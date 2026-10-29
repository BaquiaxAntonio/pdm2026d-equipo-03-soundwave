import 'commons_http_transport.dart';

CommonsHttpTransport createCommonsHttpTransport() =>
    const UnsupportedCommonsHttpTransport();

class UnsupportedCommonsHttpTransport implements CommonsHttpTransport {
  const UnsupportedCommonsHttpTransport();

  @override
  Future<CommonsHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) => throw const CommonsTransportException(
    CommonsTransportFailure.network,
    'Commons networking is unavailable on this platform.',
  );
}
