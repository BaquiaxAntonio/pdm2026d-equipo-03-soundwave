import 'dart:async';
import 'dart:convert';

import 'commons_http_transport.dart';
import 'commons_http_transport_stub.dart'
    if (dart.library.io) 'commons_http_transport_io.dart'
    as platform;
import 'commons_song_adapter.dart';

const commonsUserAgent =
    'SoundWave-Academic/0.1 '
    '(https://github.com/BaquiaxAntonio/pdm2026d-equipo-03-soundwave; '
    'https://github.com/JavEstrada09)';

const _imageInfoProperties = 'size|url|mime|extmetadata';
const _extendedMetadataFields =
    'Artist|Credit|LicenseShortName|LicenseUrl|UsageTerms|'
    'AttributionRequired|Copyrighted|Restrictions';

enum CommonsApiFailure {
  network,
  timeout,
  authentication,
  rateLimited,
  server,
  invalidResponse,
}

class CommonsApiException implements Exception {
  const CommonsApiException(
    this.failure,
    this.message, {
    this.statusCode,
    this.retryAfter,
    this.cause,
  });

  final CommonsApiFailure failure;
  final String message;
  final int? statusCode;
  final Duration? retryAfter;
  final Object? cause;

  @override
  String toString() => 'CommonsApiException($failure): $message';
}

abstract interface class CommonsCatalogSource {
  Future<List<CommonsCatalogItem>> search(String query);

  Future<CommonsCatalogItem?> findByPageId(String pageId);
}

class CommonsApiClient implements CommonsCatalogSource {
  CommonsApiClient({
    CommonsHttpTransport? transport,
    this.timeout = const Duration(seconds: 15),
    this.userAgent = commonsUserAgent,
    Uri? endpoint,
  }) : _transport = transport ?? platform.createCommonsHttpTransport(),
       endpoint =
           endpoint ?? Uri.parse('https://commons.wikimedia.org/w/api.php');

  final CommonsHttpTransport _transport;
  final Duration timeout;
  final String userAgent;
  final Uri endpoint;

  @override
  Future<List<CommonsCatalogItem>> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final response = await _request({
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'generator': 'search',
      'gsrsearch': normalizedQuery,
      'gsrnamespace': '6',
      'gsrlimit': '20',
      'prop': 'imageinfo',
      'iiprop': _imageInfoProperties,
      'iiextmetadatafilter': _extendedMetadataFields,
    });
    return _parseItems(response).where(_isAudioItem).toList(growable: false);
  }

  @override
  Future<CommonsCatalogItem?> findByPageId(String pageId) async {
    final numericPageId = int.tryParse(pageId);
    if (numericPageId == null || numericPageId <= 0) return null;

    final response = await _request({
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'pageids': numericPageId.toString(),
      'prop': 'imageinfo',
      'iiprop': _imageInfoProperties,
      'iiextmetadatafilter': _extendedMetadataFields,
    });
    final items = _parseItems(
      response,
    ).where(_isAudioItem).toList(growable: false);
    if (items.isEmpty) return null;
    if (items.length != 1 || items.single.song.sourceId != pageId) {
      throw const CommonsApiException(
        CommonsApiFailure.invalidResponse,
        'Commons returned metadata for an unexpected page.',
      );
    }
    return items.single;
  }

  Future<Object?> _request(Map<String, String> parameters) async {
    final uri = endpoint.replace(queryParameters: parameters);
    late CommonsHttpResponse response;
    try {
      response = await _transport
          .get(
            uri,
            headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
            timeout: timeout,
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw CommonsApiException(
        CommonsApiFailure.timeout,
        'Commons request timed out.',
        cause: error,
      );
    } on CommonsTransportException catch (error) {
      throw CommonsApiException(
        error.failure == CommonsTransportFailure.timeout
            ? CommonsApiFailure.timeout
            : CommonsApiFailure.network,
        error.message,
        cause: error,
      );
    }

    _validateStatus(response);

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw CommonsApiException(
        CommonsApiFailure.invalidResponse,
        'Commons returned invalid JSON.',
        statusCode: response.statusCode,
        cause: error,
      );
    }

    final root = decoded is Map<String, Object?> ? decoded : null;
    final apiError = root?['error'];
    if (apiError is Map<String, Object?>) {
      throw _mapApiError(apiError);
    }
    if (root == null) {
      throw CommonsApiException(
        CommonsApiFailure.invalidResponse,
        'Commons returned an invalid response object.',
        statusCode: response.statusCode,
      );
    }
    return root;
  }

  void _validateStatus(CommonsHttpResponse response) {
    final status = response.statusCode;
    if (status == 200) return;
    if (status == 401 || status == 403) {
      throw CommonsApiException(
        CommonsApiFailure.authentication,
        'Commons rejected the client credentials or access.',
        statusCode: status,
      );
    }
    if (status == 408 || status == 504) {
      throw CommonsApiException(
        CommonsApiFailure.timeout,
        'Commons timed out while processing the request.',
        statusCode: status,
      );
    }
    if (status == 429) {
      throw CommonsApiException(
        CommonsApiFailure.rateLimited,
        'Commons temporarily limited requests.',
        statusCode: status,
        retryAfter: _retryAfter(response.headers['retry-after']),
      );
    }
    throw CommonsApiException(
      status >= 500
          ? CommonsApiFailure.server
          : CommonsApiFailure.invalidResponse,
      'Commons returned HTTP $status.',
      statusCode: status,
    );
  }

  CommonsApiException _mapApiError(Map<String, Object?> error) {
    final code = error['code'] is String ? error['code']! as String : '';
    final info = error['info'] is String
        ? error['info']! as String
        : 'Commons returned an API error.';
    final normalizedCode = code.toLowerCase();
    final failure = switch (normalizedCode) {
      'badtoken' ||
      'permissiondenied' ||
      'readapidenied' => CommonsApiFailure.authentication,
      'ratelimited' || 'maxlag' => CommonsApiFailure.rateLimited,
      _ => CommonsApiFailure.invalidResponse,
    };
    return CommonsApiException(failure, info);
  }

  Duration? _retryAfter(String? value) {
    final seconds = value == null ? null : int.tryParse(value.trim());
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  bool _isAudioItem(CommonsCatalogItem item) =>
      item.mimeType?.toLowerCase().startsWith('audio/') ?? false;

  List<CommonsCatalogItem> _parseItems(Object? response) {
    try {
      return parseCommonsCatalogResponse(response);
    } on FormatException catch (error) {
      throw CommonsApiException(
        CommonsApiFailure.invalidResponse,
        'Commons response did not contain a valid page list.',
        cause: error,
      );
    }
  }
}
