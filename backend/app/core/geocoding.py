"""Free location autocomplete + geocoding.

Uses OpenStreetMap-based providers that need no API key:
  1. Photon (photon.komoot.io) — purpose-built type-ahead, returns coords directly.
  2. Nominatim (nominatim.openstreetmap.org) — fallback for coverage gaps.

Both are free. Nominatim's usage policy requires a descriptive User-Agent and
asks for <=1 req/sec, so it is only used when Photon returns nothing.
"""

from typing import List, Optional

import httpx

from app.schemas.schemas import LocationAutocompleteSuggestion

PHOTON_URL = "https://photon.komoot.io/api/"
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

# Nominatim requires a real identifying User-Agent.
_USER_AGENT = "CityCompanionApp/1.0 (location-autocomplete)"

# Restrict results to India (the app's only market).
_INDIA_LAT = 22.5937
_INDIA_LNG = 78.9629
# India bounding box: minLon, minLat, maxLon, maxLat
_INDIA_BBOX = "68.0,6.5,97.5,37.5"
_INDIA_COUNTRY_CODE = "in"


class LocationServiceError(Exception):
    pass


def _photon_description(props: dict) -> Optional[str]:
    """Build a human-readable label from Photon feature properties."""
    parts = [
        props.get("name"),
        props.get("street"),
        props.get("district"),
        props.get("city") or props.get("county"),
        props.get("state"),
        props.get("country"),
    ]
    seen = []
    for part in parts:
        if part and part not in seen:
            seen.append(part)
    return ", ".join(seen) if seen else None


async def _autocomplete_photon(
    client: httpx.AsyncClient, query: str
) -> List[LocationAutocompleteSuggestion]:
    response = await client.get(
        PHOTON_URL,
        params={
            "q": query,
            "limit": 8,
            "lat": _INDIA_LAT,
            "lon": _INDIA_LNG,
            "bbox": _INDIA_BBOX,
        },
        headers={"User-Agent": _USER_AGENT},
    )
    response.raise_for_status()
    payload = response.json()

    suggestions: List[LocationAutocompleteSuggestion] = []
    for feature in payload.get("features", []):
        geometry = feature.get("geometry", {})
        coords = geometry.get("coordinates")  # [lng, lat]
        props = feature.get("properties", {})
        if not coords or len(coords) < 2:
            continue
        # Drop anything outside India (bbox can leak across borders).
        country_code = str(props.get("countrycode") or "").lower()
        if country_code and country_code != _INDIA_COUNTRY_CODE:
            continue
        description = _photon_description(props)
        if not description:
            continue
        osm_type = str(props.get("osm_type") or "")
        osm_id = str(props.get("osm_id") or "")
        place_id = f"{osm_type}{osm_id}" or description
        suggestions.append(
            LocationAutocompleteSuggestion(
                place_id=place_id,
                description=description,
                lat=float(coords[1]),
                lng=float(coords[0]),
            )
        )
    return suggestions[:5]


async def _autocomplete_nominatim(
    client: httpx.AsyncClient, query: str
) -> List[LocationAutocompleteSuggestion]:
    response = await client.get(
        NOMINATIM_URL,
        params={
            "q": query,
            "format": "jsonv2",
            "limit": 5,
            "addressdetails": 0,
            "countrycodes": _INDIA_COUNTRY_CODE,
        },
        headers={"User-Agent": _USER_AGENT},
    )
    response.raise_for_status()
    results = response.json()

    suggestions: List[LocationAutocompleteSuggestion] = []
    for item in results:
        lat = item.get("lat")
        lng = item.get("lon")
        description = item.get("display_name")
        if lat is None or lng is None or not description:
            continue
        suggestions.append(
            LocationAutocompleteSuggestion(
                place_id=str(item.get("place_id") or description),
                description=description,
                lat=float(lat),
                lng=float(lng),
            )
        )
    return suggestions


async def autocomplete_locations(query: str) -> List[LocationAutocompleteSuggestion]:
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            try:
                suggestions = await _autocomplete_photon(client, query)
            except (httpx.RequestError, httpx.HTTPStatusError, ValueError):
                suggestions = []

            if not suggestions:
                suggestions = await _autocomplete_nominatim(client, query)

            return suggestions
    except (httpx.RequestError, httpx.HTTPStatusError, ValueError) as exc:
        raise LocationServiceError("Location autocomplete request failed") from exc
