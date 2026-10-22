import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/search/data/commons_api_client.dart';
import 'package:soundwave/features/search/data/commons_http_transport.dart';

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
      'size|url|mime|extmetadata',
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
