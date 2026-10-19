import 'dart:async';
import 'dart:io';
import '../../../core/errors/repository_exception.dart';
import '../../../core/models/song.dart';
import 'download_input.dart';

class PermittedAudio {
  const PermittedAudio(this.uri, {required this.downloadAllowed});
  final Uri uri;
  final bool downloadAllowed;
}

/// The API owner supplies an explicit permitted URL resolver, never an endpoint
/// guessed by this module. Production requires HTTPS; HTTP is test-only.
class HttpAudioDownloader {
  HttpAudioDownloader(
    this.resolve, {
    this.allowLocalHttp = false,
    this.timeout = const Duration(seconds: 30),
  });
  final Future<PermittedAudio> Function(Song) resolve;
  final bool allowLocalHttp;
  final Duration timeout;

  Future<DownloadInput> open(Song song) async {
    final audio = await resolve(song);
    final local =
        allowLocalHttp &&
        audio.uri.scheme == 'http' &&
        ['localhost', '127.0.0.1', '::1'].contains(audio.uri.host);
    if (!audio.downloadAllowed || (audio.uri.scheme != 'https' && !local)) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidData,
        'Audio download is not permitted.',
      );
    }
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(audio.uri).timeout(timeout);
      // Resolve redirects through the provider adapter, preserving its permission
      // and scheme checks instead of silently following an unverified location.
      request.followRedirects = false;
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw RepositoryException(
          RepositoryErrorCode.network,
          'Audio server returned ${response.statusCode}.',
        );
      }
      if (![
        'audio/wav',
        'audio/x-wav',
        'audio/wave',
      ].contains(response.headers.contentType?.mimeType)) {
        throw const RepositoryException(
          RepositoryErrorCode.invalidData,
          'Unsupported audio response.',
        );
      }
      Stream<List<int>> bytes() async* {
        try {
          yield* response.timeout(timeout);
        } finally {
          client.close(force: true);
        }
      }

      return DownloadInput(
        bytes(),
        totalBytes: response.contentLength < 0 ? null : response.contentLength,
        close: () => client.close(force: true),
      );
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }
}
