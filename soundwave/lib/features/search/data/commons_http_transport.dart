enum CommonsTransportFailure { network, timeout }

class CommonsTransportException implements Exception {
  const CommonsTransportException(this.failure, this.message, {this.cause});

  final CommonsTransportFailure failure;
  final String message;
  final Object? cause;

  @override
  String toString() => 'CommonsTransportException($failure): $message';
}

class CommonsHttpResponse {
  CommonsHttpResponse({
    required this.statusCode,
    required this.body,
    Map<String, String> headers = const {},
  }) : headers = Map.unmodifiable({
         for (final entry in headers.entries)
           entry.key.toLowerCase(): entry.value,
       });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

abstract interface class CommonsHttpTransport {
  Future<CommonsHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  });
}
