import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/search/data/commons_api_client.dart';
import 'package:soundwave/features/search/data/commons_http_transport.dart';
import 'package:soundwave/features/search/data/commons_song_adapter.dart';

void main() {
  late String realResponse;

  setUpAll(() async {
    realResponse = await File(
      'test/features/search/fixtures/welcome_to_noxville_response.json',
    ).readAsString();
  });

  test('busca con parámetros, User-Agent y timeout acordados', () async {
    final transport = FakeCommonsHttpTransport(
      (_) async => CommonsHttpResponse(statusCode: 200, body: realResponse),
    );
    final client = CommonsApiClient(
      transport: transport,
      timeout: const Duration(seconds: 7),
      userAgent: 'SoundWave-Test/1.0 (contact@example.test)',
    );

    final items = await client.search('  Noxville  ');

    expect(items, hasLength(1));
    expect(items.single.song.id, 'wikimedia_commons:157450501');
    expect(items.single.licenseShortName, 'CC BY 4.0');
    expect(transport.lastUri?.queryParameters, containsPair('action', 'query'));
    expect(
      transport.lastUri?.queryParameters,
      containsPair('generator', 'search'),
    );
    expect(
      transport.lastUri?.queryParameters,
      containsPair('gsrsearch', 'Noxville'),
    );
    expect(
      transport.lastUri?.queryParameters,
      containsPair('gsrnamespace', '6'),
    );
    expect(
      transport.lastUri?.queryParameters['iiprop'],
      'size|url|mime|sha1|extmetadata',
    );
    expect(
      transport.lastHeaders?['User-Agent'],
      'SoundWave-Test/1.0 (contact@example.test)',
    );
    expect(transport.lastHeaders?['Accept'], 'application/json');
    expect(transport.lastTimeout, const Duration(seconds: 7));
  });

  test(
    'consulta metadatos por pageid sin usar la URL como identidad',
    () async {
      final transport = FakeCommonsHttpTransport(
        (_) async => CommonsHttpResponse(statusCode: 200, body: realResponse),
      );
      final client = CommonsApiClient(transport: transport);

      final item = await client.findByPageId('157450501');

      expect(item?.song.sourceId, '157450501');
      expect(
        transport.lastUri?.queryParameters,
        containsPair('pageids', '157450501'),
      );
      expect(transport.lastUri?.queryParameters, isNot(contains('generator')));
    },
  );

  test('no solicita metadatos para un pageid inválido', () async {
    final transport = FakeCommonsHttpTransport(
      (_) async => throw StateError('No debe ejecutarse.'),
    );
    final client = CommonsApiClient(transport: transport);

    expect(await client.findByPageId('no-numérico'), isNull);
    expect(transport.callCount, 0);
  });

  test('omite páginas incompletas sin perder las válidas', () async {
    final decoded = jsonDecode(realResponse) as Map<String, Object?>;
    final pages =
        ((decoded['query']! as Map<String, Object?>)['pages']!
            as List<Object?>);
    pages.insert(0, {
      'pageid': 10,
      'title': 'File:Incomplete.wav',
      'imageinfo': [
        {'mime': 'audio/wav', 'extmetadata': <String, Object?>{}},
      ],
    });
    final transport = FakeCommonsHttpTransport(
      (_) async =>
          CommonsHttpResponse(statusCode: 200, body: jsonEncode(decoded)),
    );

    final items = await CommonsApiClient(transport: transport).search('audio');

    expect(items, hasLength(1));
    expect(items.single.song.sourceId, '157450501');
  });

  test('acepta una respuesta vacía válida', () async {
    final transport = FakeCommonsHttpTransport(
      (_) async => CommonsHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'batchcomplete': true,
          'query': {'pages': <Object?>[]},
        }),
      ),
    );

    final items = await CommonsApiClient(transport: transport).search('none');

    expect(items, isEmpty);
  });

  test('rechaza JSON o estructura inválidos', () async {
    for (final body in [
      'not-json',
      jsonEncode({'query': <String, Object?>{}}),
    ]) {
      final transport = FakeCommonsHttpTransport(
        (_) async => CommonsHttpResponse(statusCode: 200, body: body),
      );
      final client = CommonsApiClient(transport: transport);

      await expectLater(
        client.search('audio'),
        throwsA(
          isA<CommonsApiException>().having(
            (error) => error.failure,
            'failure',
            CommonsApiFailure.invalidResponse,
          ),
        ),
      );
    }
  });

  test('distingue autenticación, timeout HTTP, cuota y servidor', () async {
    final cases = <int, CommonsApiFailure>{
      401: CommonsApiFailure.authentication,
      403: CommonsApiFailure.authentication,
      408: CommonsApiFailure.timeout,
      429: CommonsApiFailure.rateLimited,
      503: CommonsApiFailure.server,
    };
    for (final entry in cases.entries) {
      final transport = FakeCommonsHttpTransport(
        (_) async => CommonsHttpResponse(
          statusCode: entry.key,
          body: '{}',
          headers: entry.key == 429 ? {'Retry-After': '12'} : const {},
        ),
      );
      final client = CommonsApiClient(transport: transport);

      await expectLater(
        client.search('audio'),
        throwsA(
          isA<CommonsApiException>()
              .having((error) => error.failure, 'failure', entry.value)
              .having(
                (error) => error.retryAfter,
                'retryAfter',
                entry.key == 429 ? const Duration(seconds: 12) : null,
              ),
        ),
      );
    }
  });

  test('distingue errores de API aunque HTTP sea 200', () async {
    final transport = FakeCommonsHttpTransport(
      (_) async => CommonsHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'error': {'code': 'ratelimited', 'info': 'Wait before retrying.'},
        }),
      ),
    );

    await expectLater(
      CommonsApiClient(transport: transport).search('audio'),
      throwsA(
        isA<CommonsApiException>().having(
          (error) => error.failure,
          'failure',
          CommonsApiFailure.rateLimited,
        ),
      ),
    );
  });

  test('aplica el timeout aunque el transporte no responda', () async {
    final pending = Completer<CommonsHttpResponse>();
    final transport = FakeCommonsHttpTransport((_) => pending.future);
    final client = CommonsApiClient(
      transport: transport,
      timeout: const Duration(milliseconds: 5),
    );

    await expectLater(
      client.search('audio'),
      throwsA(
        isA<CommonsApiException>().having(
          (error) => error.failure,
          'failure',
          CommonsApiFailure.timeout,
        ),
      ),
    );
  });

  test('no inicia una consulta de búsqueda vacía', () async {
    final transport = FakeCommonsHttpTransport(
      (_) async => throw StateError('No debe ejecutarse.'),
    );

    expect(await CommonsApiClient(transport: transport).search('   '), isEmpty);
    expect(transport.callCount, 0);
  });

  test('resolver autoriza únicamente la muestra documentada vigente', () async {
    final transport = FakeCommonsHttpTransport(
      (_) async => CommonsHttpResponse(statusCode: 200, body: realResponse),
    );
    final resolver = CommonsAudioResolver(
      CommonsApiClient(transport: transport),
    );

    final resolution = await resolver.resolve(_sampleSong);

    expect(resolution.downloadAllowed, isTrue);
    expect(resolution.uri.scheme, 'https');
    expect(resolution.mimeType, 'audio/wav');
    expect(resolution.fileSizeBytes, 647212);
    expect(resolution.sha1, 'd7eec8429fe6ecb42aaaa6886353406f562a1e0b');
    expect(resolution.attribution.creator, 'Sir Goose of Honker');
    expect(resolution.attribution.credit, 'Own work');
    expect(resolution.attribution.licenseName, 'CC BY 4.0');
    expect(
      resolution.attribution.licenseUrl,
      Uri.parse('https://creativecommons.org/licenses/by/4.0'),
    );
    expect(
      transport.lastUri?.queryParameters,
      containsPair('pageids', '157450501'),
    );
  });

  test('resolver rechaza metadatos insuficientes', () async {
    final resolver = CommonsAudioResolver(
      _FakeCatalogSource(item: _sampleItem(sha1: null)),
    );

    await expectLater(
      resolver.resolve(_sampleSong),
      throwsA(
        _resolutionFailure(CommonsAudioResolutionFailure.missingMetadata),
      ),
    );
  });

  test('URL y nombre de licencia no bastan ante restricciones', () async {
    final resolver = CommonsAudioResolver(
      _FakeCatalogSource(
        item: _sampleItem(restrictions: 'NonCommercial use only'),
      ),
    );

    await expectLater(
      resolver.resolve(_sampleSong),
      throwsA(
        _resolutionFailure(CommonsAudioResolutionFailure.permissionDenied),
      ),
    );
  });

  test('resolver rechaza identidad devuelta distinta', () async {
    final resolver = CommonsAudioResolver(
      _FakeCatalogSource(
        item: _sampleItem(
          song: const Song(
            id: 'wikimedia_commons:999',
            title: 'Otro archivo',
            artist: 'Otro autor',
            provider: 'wikimedia_commons',
            sourceId: '999',
          ),
        ),
      ),
    );

    await expectLater(
      resolver.resolve(_sampleSong),
      throwsA(
        _resolutionFailure(CommonsAudioResolutionFailure.identityMismatch),
      ),
    );
  });

  test(
    'resolver rechaza canciones de otro proveedor sin consultar Commons',
    () async {
      final source = _FakeCatalogSource(item: _sampleItem());
      final resolver = CommonsAudioResolver(source);
      const song = Song(
        id: 'otro:157450501',
        title: 'Welcome to Noxville',
        artist: 'Sir Goose of Honker',
        provider: 'otro',
        sourceId: '157450501',
      );

      await expectLater(
        resolver.resolve(song),
        throwsA(
          _resolutionFailure(CommonsAudioResolutionFailure.unsupportedProvider),
        ),
      );
      expect(source.findCalls, 0);
    },
  );

  test('resolver rechaza URL que no sea HTTPS aprobada', () async {
    final resolver = CommonsAudioResolver(
      _FakeCatalogSource(
        item: _sampleItem(
          mediaUrl:
              'http://upload.wikimedia.org/wikipedia/commons/7/76/'
              'Welcome_to_Noxville.wav',
        ),
      ),
    );

    await expectLater(
      resolver.resolve(_sampleSong),
      throwsA(_resolutionFailure(CommonsAudioResolutionFailure.invalidUrl)),
    );
  });

  test('MIME WAV no basta si la evidencia del archivo cambió', () async {
    final resolver = CommonsAudioResolver(
      _FakeCatalogSource(
        item: _sampleItem(sha1: '0000000000000000000000000000000000000000'),
      ),
    );

    await expectLater(
      resolver.resolve(_sampleSong),
      throwsA(
        _resolutionFailure(CommonsAudioResolutionFailure.unsupportedAudio),
      ),
    );
  });

  test('resolver propaga errores de API sin convertirlos en permiso', () async {
    const apiError = CommonsApiException(
      CommonsApiFailure.rateLimited,
      'Límite temporal.',
      statusCode: 429,
    );
    final resolver = CommonsAudioResolver(_FakeCatalogSource(error: apiError));

    await expectLater(resolver.resolve(_sampleSong), throwsA(same(apiError)));
  });
}

const _sampleSong = Song(
  id: 'wikimedia_commons:157450501',
  title: 'Welcome to Noxville',
  artist: 'Sir Goose of Honker',
  durationMs: 6741,
  provider: 'wikimedia_commons',
  sourceId: '157450501',
);

Matcher _resolutionFailure(CommonsAudioResolutionFailure failure) =>
    isA<CommonsAudioResolutionException>().having(
      (error) => error.failure,
      'failure',
      failure,
    );

CommonsCatalogItem _sampleItem({
  Song song = _sampleSong,
  String? mediaUrl =
      'https://upload.wikimedia.org/wikipedia/commons/7/76/'
      'Welcome_to_Noxville.wav',
  String? mimeType = 'audio/wav',
  int? fileSizeBytes = 647212,
  String? sha1 = 'd7eec8429fe6ecb42aaaa6886353406f562a1e0b',
  String? creditText = 'Own work',
  String? licenseShortName = 'CC BY 4.0',
  String? licenseUrl = 'https://creativecommons.org/licenses/by/4.0',
  String? usageTerms = 'Creative Commons Attribution 4.0',
  bool? attributionRequired = true,
  bool? copyrighted = true,
  String? restrictions = '',
}) => CommonsCatalogItem(
  song: song,
  sourcePageUrl: Uri.parse(
    'https://commons.wikimedia.org/wiki/File:Welcome_to_Noxville.wav',
  ),
  artistHtml: song.artist,
  mediaUrl: mediaUrl == null ? null : Uri.parse(mediaUrl),
  mimeType: mimeType,
  fileSizeBytes: fileSizeBytes,
  sha1: sha1,
  creditHtml: creditText,
  creditText: creditText,
  licenseShortName: licenseShortName,
  licenseUrl: licenseUrl == null ? null : Uri.parse(licenseUrl),
  usageTerms: usageTerms,
  attributionRequired: attributionRequired,
  copyrighted: copyrighted,
  restrictions: restrictions,
);

class _FakeCatalogSource implements CommonsCatalogSource {
  _FakeCatalogSource({this.item, this.error});

  final CommonsCatalogItem? item;
  final Object? error;
  int findCalls = 0;

  @override
  Future<CommonsCatalogItem?> findByPageId(String pageId) async {
    findCalls++;
    final failure = error;
    if (failure != null) throw failure;
    return item;
  }

  @override
  Future<List<CommonsCatalogItem>> search(String query) =>
      throw UnimplementedError();
}

class FakeCommonsHttpTransport implements CommonsHttpTransport {
  FakeCommonsHttpTransport(this.handler);

  final Future<CommonsHttpResponse> Function(Uri uri) handler;
  int callCount = 0;
  Uri? lastUri;
  Map<String, String>? lastHeaders;
  Duration? lastTimeout;

  @override
  Future<CommonsHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) {
    callCount++;
    lastUri = uri;
    lastHeaders = Map.of(headers);
    lastTimeout = timeout;
    return handler(uri);
  }
}
