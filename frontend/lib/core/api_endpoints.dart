const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://city-companion.onrender.com/v1',
);

Uri buildChatWebSocketUri({
  required String token,
  required String conversationId,
}) {
  final apiUri = Uri.parse(apiBaseUrl);
  final wsScheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
  final normalizedPath = apiUri.path.endsWith('/')
      ? apiUri.path.substring(0, apiUri.path.length - 1)
      : apiUri.path;

  return apiUri.replace(
    scheme: wsScheme,
    path: '$normalizedPath/chat/ws',
    queryParameters: {
      'token': token,
      'conv_id': conversationId,
    },
  );
}
