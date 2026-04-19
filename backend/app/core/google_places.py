from typing import List, Optional

import httpx

from app.core.config import settings
from app.schemas.schemas import LocationAutocompleteSuggestion

NEW_AUTOCOMPLETE_URL = "https://places.googleapis.com/v1/places:autocomplete"
NEW_PLACE_DETAILS_URL = "https://places.googleapis.com/v1/places/{place_id}"
LEGACY_AUTOCOMPLETE_URL = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
LEGACY_PLACE_DETAILS_URL = "https://maps.googleapis.com/maps/api/place/details/json"


class GooglePlacesServiceError(Exception):
    pass


async def _fetch_coordinates_new(
    client: httpx.AsyncClient, place_id: str
) -> Optional[tuple[float, float]]:
    response = await client.get(
        NEW_PLACE_DETAILS_URL.format(place_id=place_id),
        headers={
            "X-Goog-Api-Key": settings.GOOGLE_PLACES_API_KEY or "",
            "X-Goog-FieldMask": "location",
        },
    )
    response.raise_for_status()
    payload = response.json()
    location = payload.get("location", {})
    lat = location.get("latitude")
    lng = location.get("longitude")
    if lat is None or lng is None:
        return None
    return float(lat), float(lng)


async def _fetch_coordinates_legacy(
    client: httpx.AsyncClient, place_id: str
) -> Optional[tuple[float, float]]:
    response = await client.get(
        LEGACY_PLACE_DETAILS_URL,
        params={
            "place_id": place_id,
            "key": settings.GOOGLE_PLACES_API_KEY,
            "fields": "geometry",
        },
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("status") != "OK":
        return None

    location = payload.get("result", {}).get("geometry", {}).get("location", {})
    lat = location.get("lat")
    lng = location.get("lng")
    if lat is None or lng is None:
        return None
    return float(lat), float(lng)


async def _autocomplete_new(client: httpx.AsyncClient, query: str) -> List[dict]:
    response = await client.post(
        NEW_AUTOCOMPLETE_URL,
        headers={
            "X-Goog-Api-Key": settings.GOOGLE_PLACES_API_KEY or "",
            "X-Goog-FieldMask": "suggestions.placePrediction.placeId,suggestions.placePrediction.text.text",
        },
        json={"input": query},
    )
    response.raise_for_status()
    payload = response.json()
    suggestions_payload = payload.get("suggestions", [])
    predictions = []
    for suggestion in suggestions_payload:
        place_prediction = suggestion.get("placePrediction", {})
        text_payload = place_prediction.get("text", {})
        predictions.append(
            {
                "place_id": place_prediction.get("placeId"),
                "description": text_payload.get("text"),
            }
        )
    return predictions[:5]


async def _autocomplete_legacy(client: httpx.AsyncClient, query: str) -> List[dict]:
    response = await client.get(
        LEGACY_AUTOCOMPLETE_URL,
        params={
            "input": query,
            "key": settings.GOOGLE_PLACES_API_KEY,
        },
    )
    response.raise_for_status()
    payload = response.json()
    status = payload.get("status")
    if status not in {"OK", "ZERO_RESULTS"}:
        raise GooglePlacesServiceError("Autocomplete provider returned an error")
    predictions = payload.get("predictions", [])[:5]
    return [
        {"place_id": item.get("place_id"), "description": item.get("description")}
        for item in predictions
    ]


async def autocomplete_locations(query: str) -> List[LocationAutocompleteSuggestion]:
    if not settings.GOOGLE_PLACES_API_KEY:
        raise GooglePlacesServiceError("Google Places API key is not configured")

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            try:
                predictions = await _autocomplete_new(client, query)
                coordinate_fetcher = _fetch_coordinates_new
            except (httpx.RequestError, httpx.HTTPStatusError, ValueError):
                predictions = await _autocomplete_legacy(client, query)
                coordinate_fetcher = _fetch_coordinates_legacy

            suggestions: List[LocationAutocompleteSuggestion] = []
            for item in predictions:
                place_id = item.get("place_id")
                description = item.get("description")
                if not place_id or not description:
                    continue

                try:
                    coordinates = await coordinate_fetcher(client, place_id)
                except (httpx.RequestError, httpx.HTTPStatusError, ValueError):
                    continue

                if not coordinates:
                    continue

                lat, lng = coordinates
                suggestions.append(
                    LocationAutocompleteSuggestion(
                        place_id=place_id,
                        description=description,
                        lat=lat,
                        lng=lng,
                    )
                )

            return suggestions
    except (httpx.RequestError, httpx.HTTPStatusError, ValueError, GooglePlacesServiceError) as exc:
        raise GooglePlacesServiceError("Google Places request failed") from exc
