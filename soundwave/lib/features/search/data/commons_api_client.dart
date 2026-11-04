import 'dart:async';
import 'dart:convert';

import '../../../core/models/song.dart';
import 'commons_http_transport.dart';
import 'commons_http_transport_stub.dart'
    if (dart.library.io) 'commons_http_transport_io.dart'
    as platform;
import 'commons_song_adapter.dart';

const commonsUserAgent =
    'SoundWave-Academic/0.1 '
    '(https://github.com/BaquiaxAntonio/pdm2026d-equipo-03-soundwave; '
    'https://github.com/JavEstrada09)';

const _imageInfoProperties = 'size|url|mime|sha1|extmetadata';
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

enum CommonsAudioResolutionFailure {
  unsupportedProvider,
  identityMismatch,
  undocumentedSource,
  missingMetadata,
  permissionDenied,
  invalidUrl,
  unsupportedAudio,
}

class CommonsAudioResolutionException implements Exception {
  const CommonsAudioResolutionException(this.failure, this.message);

  final CommonsAudioResolutionFailure failure;
  final String message;

  @override
  String toString() => 'CommonsAudioResolutionException($failure): $message';
}

class CommonsAudioAttribution {
  const CommonsAudioAttribution({
    required this.title,
    required this.creator,
    required this.credit,
    required this.sourcePageUrl,
    required this.licenseName,
    required this.licenseUrl,
    required this.usageTerms,
  });

  final String title;
  final String creator;
  final String? credit;
  final Uri sourcePageUrl;
  final String licenseName;
  final Uri? licenseUrl;
  final String usageTerms;
}

/// A current, evidence-backed decision. Attribution is returned to the caller
/// because the download contract cannot persist it yet.
class CommonsAudioResolution {
  const CommonsAudioResolution({
    required this.song,
    required this.uri,
    required this.downloadAllowed,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.sha1,
    required this.attribution,
  });

  final Uri uri;
  final Song song;
  final bool downloadAllowed;
  final String mimeType;
  final int fileSizeBytes;
  final String sha1;
  final CommonsAudioAttribution attribution;
}

class CommonsAudioResolver {
  const CommonsAudioResolver(this.source);

  final CommonsCatalogSource source;

  Future<CommonsAudioResolution> resolve(Song song) async {
    if (song.provider != commonsProviderId) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.unsupportedProvider,
        'The song does not belong to Wikimedia Commons.',
      );
    }
    if (song.sourceId.isEmpty ||
        song.id != '$commonsProviderId:${song.sourceId}') {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.identityMismatch,
        'The song identity does not match its Commons source ID.',
      );
    }

    final item = await source.findByPageId(song.sourceId);
    if (item == null) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.missingMetadata,
        'Commons did not return current metadata for this file.',
      );
    }
    if (item.song.provider != commonsProviderId ||
        item.song.sourceId != song.sourceId ||
        item.song.id != song.id) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.identityMismatch,
        'Commons returned metadata for a different file.',
      );
    }

    final mediaUrl = item.mediaUrl;
    final mimeType = item.mimeType;
    final fileSizeBytes = item.fileSizeBytes;
    final sha1 = item.sha1;
    final credit = item.creditText;
    final licenseName = item.licenseShortName;
    final licenseUrl = item.licenseUrl;
    final usageTerms = item.usageTerms;
    final restrictions = item.restrictions;
    final sourcePageUrl = item.sourcePageUrl;
    if (mediaUrl == null ||
        mimeType == null ||
        fileSizeBytes == null ||
        sha1 == null ||
        licenseName == null ||
        usageTerms == null ||
        sourcePageUrl == null ||
        fileSizeBytes <= 0 ||
        !RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(sha1)) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.missingMetadata,
        'Commons metadata is insufficient for an offline permission decision.',
      );
    }

    if (!hasSupportedCommonsLicense(item) ||
        (restrictions != null && restrictions.trim().isNotEmpty)) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.permissionDenied,
        'Esta pista no tiene una licencia libre compatible y verificable.',
      );
    }

    if (mediaUrl.scheme != 'https' ||
        mediaUrl.host != 'upload.wikimedia.org' ||
        !mediaUrl.path.startsWith('/wikipedia/commons/') ||
        mediaUrl.userInfo.isNotEmpty ||
        mediaUrl.hasPort ||
        mediaUrl.fragment.isNotEmpty) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.invalidUrl,
        'Commons returned an unapproved audio URL.',
      );
    }
    final normalizedMime = mimeType.trim().toLowerCase();
    if (!_transportMimeTypes.contains(normalizedMime) ||
        !RegExp(
          r'\.(wav|ogg|oga|opus)$',
          caseSensitive: false,
        ).hasMatch(mediaUrl.path)) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.unsupportedAudio,
        'El formato de esta pista todavía no es compatible (WAV u Ogg).',
      );
    }

    return CommonsAudioResolution(
      song: Song.fromMap({
        ...item.song.toMap(),
        'license': licenseName,
        'attribution': credit,
        'license_url': licenseUrl?.toString(),
      }),
      uri: mediaUrl,
      downloadAllowed: true,
      mimeType: normalizedMime,
      fileSizeBytes: fileSizeBytes,
      sha1: sha1.trim().toLowerCase(),
      attribution: CommonsAudioAttribution(
        title: item.song.title,
        creator: item.song.artist,
        credit: credit,
        sourcePageUrl: sourcePageUrl,
        licenseName: licenseName,
        licenseUrl: licenseUrl,
        usageTerms: usageTerms,
      ),
    );
  }
}

const _transportMimeTypes = {
  'audio/wav',
  'audio/x-wav',
  'audio/wave',
  'audio/ogg',
  'application/ogg',
  'audio/opus',
};

/// Licenses permitting redistribution, with provider metadata retained as-is.
/// This is evaluated from fresh file metadata rather than a hard-coded song ID.
bool hasSupportedCommonsLicense(CommonsCatalogItem item) {
  if (item.restrictions?.trim().isNotEmpty ?? false) return false;
  if (item.licenseShortName?.toLowerCase() == 'public domain' &&
      item.copyrighted == false) {
    return true;
  }
  final uri = item.licenseUrl;
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'creativecommons.org' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  return RegExp(
    r'^/(licenses/(by|by-sa)/(1\.0|2\.0|2\.5|3\.0|4\.0)|publicdomain/zero/1\.0)/?$',
  ).hasMatch(uri.path);
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
      'gsrsearch': '$normalizedQuery filetype:audio',
      'gsrnamespace': '6',
      'gsrlimit': '20',
      'prop': 'imageinfo',
      'iiprop': _imageInfoProperties,
      'iiextmetadatafilter': _extendedMetadataFields,
    });
    return _parseItems(response)
        .where((item) => _isAudioItem(item) && hasSupportedCommonsLicense(item))
        .toList(growable: false);
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
      _transportMimeTypes.contains(item.mimeType?.toLowerCase());

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
