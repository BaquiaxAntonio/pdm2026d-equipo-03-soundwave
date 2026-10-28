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
  final String credit;
  final Uri sourcePageUrl;
  final String licenseName;
  final Uri licenseUrl;
  final String usageTerms;
}

/// A current, evidence-backed decision. Attribution is returned to the caller
/// because the download contract cannot persist it yet.
class CommonsAudioResolution {
  const CommonsAudioResolution({
    required this.uri,
    required this.downloadAllowed,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.sha1,
    required this.attribution,
  });

  final Uri uri;
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

    final evidence = _documentedAudioEvidence[song.sourceId];
    if (evidence == null) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.undocumentedSource,
        'No reviewed offline permission exists for this Commons file.',
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
    if (mediaUrl == null ||
        mimeType == null ||
        fileSizeBytes == null ||
        sha1 == null ||
        credit == null ||
        licenseName == null ||
        licenseUrl == null ||
        usageTerms == null ||
        item.attributionRequired == null ||
        item.copyrighted == null ||
        restrictions == null) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.missingMetadata,
        'Commons metadata is insufficient for an offline permission decision.',
      );
    }

    if (licenseName.trim() != evidence.licenseName ||
        !_sameLicense(licenseUrl, evidence.licenseUrl) ||
        usageTerms.trim() != evidence.usageTerms ||
        item.attributionRequired != true ||
        item.copyrighted != true ||
        restrictions.trim().isNotEmpty) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.permissionDenied,
        'Current Commons terms do not match the reviewed offline permission.',
      );
    }

    if (!_isExpectedHttpsUrl(mediaUrl, evidence)) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.invalidUrl,
        'Commons returned an unapproved audio URL.',
      );
    }
    final normalizedMime = mimeType.trim().toLowerCase();
    if (!_transportMimeTypes.contains(normalizedMime) ||
        fileSizeBytes != evidence.fileSizeBytes ||
        sha1.trim().toLowerCase() != evidence.sha1 ||
        item.song.title != evidence.title ||
        item.song.artist != evidence.creator ||
        item.sourcePageUrl != evidence.sourcePageUrl) {
      throw const CommonsAudioResolutionException(
        CommonsAudioResolutionFailure.unsupportedAudio,
        'Current file metadata no longer matches the reviewed WAV evidence.',
      );
    }

    return CommonsAudioResolution(
      uri: mediaUrl,
      downloadAllowed: true,
      mimeType: normalizedMime,
      fileSizeBytes: fileSizeBytes,
      sha1: sha1.trim().toLowerCase(),
      attribution: CommonsAudioAttribution(
        title: item.song.title,
        creator: item.song.artist,
        credit: credit,
        sourcePageUrl: item.sourcePageUrl,
        licenseName: licenseName,
        licenseUrl: licenseUrl,
        usageTerms: usageTerms,
      ),
    );
  }
}

const _transportMimeTypes = {'audio/wav', 'audio/x-wav', 'audio/wave'};

bool _sameLicense(Uri actual, String expected) {
  final normalizedPath = actual.path.endsWith('/')
      ? actual.path.substring(0, actual.path.length - 1)
      : actual.path;
  final expectedUri = Uri.parse(expected);
  return actual.scheme == 'https' &&
      actual.host == expectedUri.host &&
      normalizedPath == expectedUri.path &&
      actual.userInfo.isEmpty &&
      !actual.hasPort &&
      actual.query.isEmpty &&
      actual.fragment.isEmpty;
}

bool _isExpectedHttpsUrl(Uri uri, _CommonsAudioEvidence evidence) =>
    uri.scheme == 'https' &&
    uri.host == evidence.mediaHost &&
    uri.path == evidence.mediaPath &&
    uri.userInfo.isEmpty &&
    !uri.hasPort &&
    uri.fragment.isEmpty;

class _CommonsAudioEvidence {
  const _CommonsAudioEvidence({
    required this.title,
    required this.creator,
    required this.sourcePageUrl,
    required this.licenseName,
    required this.licenseUrl,
    required this.usageTerms,
    required this.mediaHost,
    required this.mediaPath,
    required this.fileSizeBytes,
    required this.sha1,
  });

  final String title;
  final String creator;
  final Uri sourcePageUrl;
  final String licenseName;
  final String licenseUrl;
  final String usageTerms;
  final String mediaHost;
  final String mediaPath;
  final int fileSizeBytes;
  final String sha1;
}

final _documentedAudioEvidence = <String, _CommonsAudioEvidence>{
  '157450501': _CommonsAudioEvidence(
    title: 'Welcome to Noxville',
    creator: 'Sir Goose of Honker',
    sourcePageUrl: Uri.parse(
      'https://commons.wikimedia.org/wiki/File:Welcome_to_Noxville.wav',
    ),
    licenseName: 'CC BY 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by/4.0',
    usageTerms: 'Creative Commons Attribution 4.0',
    mediaHost: 'upload.wikimedia.org',
    mediaPath: '/wikipedia/commons/7/76/Welcome_to_Noxville.wav',
    fileSizeBytes: 647212,
    sha1: 'd7eec8429fe6ecb42aaaa6886353406f562a1e0b',
  ),
};

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
