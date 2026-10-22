import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/errors/repository_exception.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/downloads/data/http_audio_downloader.dart';
import 'audio_fixture.dart';

void main() {
  const song = Song(
    id: 'fixture:audio',
    title: 'Audio',
    artist: 'Test',
    provider: 'fixture',
    sourceId: 'audio',
  );
  late HttpServer server;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
  tearDown(() => server.close(force: true));
  HttpAudioDownloader downloader({bool allowed = true}) => HttpAudioDownloader(
    (_) async => PermittedAudio(
      Uri.parse('http://127.0.0.1:${server.port}/audio'),
      downloadAllowed: allowed,
    ),
    allowLocalHttp: true,
  );

  test(
    'streams controlled HTTP audio with length and no external provider',
    () async {
      server.listen((request) async {
        request.response.headers.contentType = ContentType('audio', 'wav');
        request.response.contentLength = 48;
        request.response.add(wavFixture());
        await request.response.close();
      });
      final input = await downloader().open(song);
      expect(input.totalBytes, 48);
      expect(await input.bytes.expand((bytes) => bytes).toList(), wavFixture());
    },
  );

  test('rejects HTTP error responses', () async {
    server.listen((request) async {
      request.response.statusCode = 503;
      await request.response.close();
    });
    await expectLater(
      downloader().open(song),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('rejects HTML instead of audio', () async {
    server.listen((request) async {
      request.response.headers.contentType = ContentType.html;
      request.response.write('<html>Error</html>');
      await request.response.close();
    });
    await expectLater(
      downloader().open(song),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('permission and production HTTPS checks run before a request', () async {
    await expectLater(
      downloader(allowed: false).open(song),
      throwsA(isA<RepositoryException>()),
    );
    final production = HttpAudioDownloader(
      (_) async => PermittedAudio(
        Uri.parse('http://127.0.0.1:${server.port}'),
        downloadAllowed: true,
      ),
    );
    await expectLater(
      production.open(song),
      throwsA(isA<RepositoryException>()),
    );
  });
}
