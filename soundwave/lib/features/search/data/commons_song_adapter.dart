import '../../../core/models/song.dart';

const _commonsProvider = 'wikimedia_commons';

/// Catalog data observed in Commons, kept separate from download permission.
///
/// Legal metadata remains here until the shared persistence model is agreed.
/// Neither [mediaUrl] nor the license fields imply that a download is allowed.
class CommonsCatalogItem {
  const CommonsCatalogItem({
    required this.song,
    required this.sourcePageUrl,
    required this.artistHtml,
    this.mediaUrl,
    this.mimeType,
    this.fileSizeBytes,
    this.creditHtml,
    this.creditText,
    this.licenseShortName,
    this.licenseUrl,
    this.usageTerms,
    this.attributionRequired,
    this.copyrighted,
    this.restrictions,
  });

  final Song song;
  final Uri sourcePageUrl;
  final String artistHtml;
  final Uri? mediaUrl;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? creditHtml;
  final String? creditText;
  final String? licenseShortName;
  final Uri? licenseUrl;
  final String? usageTerms;
  final bool? attributionRequired;
  final bool? copyrighted;
  final String? restrictions;
}

/// Converts a decoded `formatversion=2` Commons response into catalog items.
///
/// A malformed response envelope is an API failure and throws [FormatException].
/// Malformed individual pages are omitted so one bad record does not discard
/// otherwise usable results.
List<CommonsCatalogItem> parseCommonsCatalogResponse(Object? response) {
  final root = _asMap(response);
  final query = _asMap(root?['query']);
  final pages = query?['pages'];
  if (pages is! List<Object?>) {
    throw const FormatException(
      'Commons response must contain query.pages as a list.',
    );
  }

  final items = <CommonsCatalogItem>[];
  for (final page in pages) {
    final item = _parsePage(page);
    if (item != null) items.add(item);
  }
  return List.unmodifiable(items);
}

CommonsCatalogItem? _parsePage(Object? value) {
  final page = _asMap(value);
  final pageId = page?['pageid'];
  final rawTitle = _nonEmptyString(page?['title']);
  if (pageId is! int || pageId <= 0 || rawTitle == null) return null;

  final title = _normalizeTitle(rawTitle);
  final imageInfoList = page?['imageinfo'];
  if (title.isEmpty ||
      imageInfoList is! List<Object?> ||
      imageInfoList.isEmpty) {
    return null;
  }

  final imageInfo = _asMap(imageInfoList.first);
  final extendedMetadata = _asMap(imageInfo?['extmetadata']);
  final artistHtml = _metadataString(extendedMetadata, 'Artist');
  if (imageInfo == null || artistHtml == null) return null;

  final artist = _htmlToText(artistHtml);
  if (artist.isEmpty) return null;

  final sourceId = pageId.toString();
  final descriptionUrl = _absoluteUri(imageInfo['descriptionurl']);
  final creditHtml = _metadataString(extendedMetadata, 'Credit');
  final creditText = creditHtml == null ? null : _htmlToText(creditHtml);

  return CommonsCatalogItem(
    song: Song(
      id: '$_commonsProvider:$sourceId',
      title: title,
      artist: artist,
      durationMs: _durationMs(imageInfo['duration']),
      provider: _commonsProvider,
      sourceId: sourceId,
    ),
    sourcePageUrl:
        descriptionUrl ??
        Uri.https('commons.wikimedia.org', '/w/index.php', {'curid': sourceId}),
    artistHtml: artistHtml,
    mediaUrl: _absoluteUri(imageInfo['url']),
    mimeType: _nonEmptyString(imageInfo['mime']),
    fileSizeBytes: _nonNegativeInt(imageInfo['size']),
    creditHtml: creditHtml,
    creditText: creditText == null || creditText.isEmpty ? null : creditText,
    licenseShortName: _nonEmptyString(
      _metadataString(extendedMetadata, 'LicenseShortName'),
    ),
    licenseUrl: _absoluteUri(_metadataString(extendedMetadata, 'LicenseUrl')),
    usageTerms: _nonEmptyString(
      _metadataString(extendedMetadata, 'UsageTerms'),
    ),
    attributionRequired: _metadataBool(extendedMetadata, 'AttributionRequired'),
    copyrighted: _metadataBool(extendedMetadata, 'Copyrighted'),
    restrictions: _metadataString(extendedMetadata, 'Restrictions'),
  );
}

Map<String, Object?>? _asMap(Object? value) =>
    value is Map<String, Object?> ? value : null;

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _nonNegativeInt(Object? value) =>
    value is int && value >= 0 ? value : null;

String? _metadataString(Map<String, Object?>? metadata, String key) {
  final field = _asMap(metadata?[key]);
  final value = field?['value'];
  return value is String ? value : null;
}

bool? _metadataBool(Map<String, Object?>? metadata, String key) {
  final value = _metadataString(metadata, key);
  if (value == null) return null;
  return switch (value.trim().toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };
}

Uri? _absoluteUri(Object? value) {
  final text = _nonEmptyString(value);
  if (text == null) return null;
  final uri = Uri.tryParse(text);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty ? uri : null;
}

int? _durationMs(Object? value) {
  if (value is! num) return null;
  final seconds = value.toDouble();
  final milliseconds = seconds * 1000;
  if (!seconds.isFinite || seconds < 0 || !milliseconds.isFinite) return null;
  return milliseconds.round();
}

String _normalizeTitle(String value) {
  var title = value.trim().replaceFirst(
    RegExp(r'^File:\s*', caseSensitive: false),
    '',
  );
  title = title.replaceFirst(RegExp(r'\.[^./\\]+$'), '');
  return title.trim();
}

String _htmlToText(String html) {
  var text = html.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');
  text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
  text = text.replaceAllMapped(RegExp(r'&([^;\s]+);'), (match) {
    final entity = match.group(1)!;
    const named = {
      'amp': '&',
      'apos': "'",
      'gt': '>',
      'lt': '<',
      'nbsp': ' ',
      'quot': '"',
    };
    final namedValue = named[entity.toLowerCase()];
    if (namedValue != null) return namedValue;

    int? codePoint;
    if (entity.startsWith('#x') || entity.startsWith('#X')) {
      codePoint = int.tryParse(entity.substring(2), radix: 16);
    } else if (entity.startsWith('#')) {
      codePoint = int.tryParse(entity.substring(1));
    }
    if (codePoint == null ||
        codePoint < 0 ||
        codePoint > 0x10ffff ||
        (codePoint >= 0xd800 && codePoint <= 0xdfff)) {
      return match.group(0)!;
    }
    return String.fromCharCode(codePoint);
  });
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
