import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'commons_http_transport.dart';

CommonsHttpTransport createCommonsHttpTransport() =>
    const IoCommonsHttpTransport();

class IoCommonsHttpTransport implements CommonsHttpTransport {
  const IoCommonsHttpTransport();

  @override
  Future<CommonsHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.followRedirects = false;
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join().timeout(timeout);
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });
      return CommonsHttpResponse(
        statusCode: response.statusCode,
        body: body,
        headers: responseHeaders,
      );
    } on TimeoutException catch (error) {
      throw CommonsTransportException(
        CommonsTransportFailure.timeout,
        'Commons request timed out.',
        cause: error,
      );
    } on IOException catch (error) {
      throw CommonsTransportException(
        CommonsTransportFailure.network,
        'Commons could not be reached.',
        cause: error,
      );
    } finally {
      client.close(force: true);
    }
  }
}
