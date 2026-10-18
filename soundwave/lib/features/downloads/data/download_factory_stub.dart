import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/repository_exception.dart';
import '../../../core/models/song.dart';
import '../download_providers.dart';
import 'download_input.dart';

Future<DownloadInput> unavailable(Song song) async =>
    throw const RepositoryException(
      RepositoryErrorCode.network,
      'La fuente de audio aún no está configurada.',
    );

Future<DownloadSession> createSession(Ref ref) async =>
    throw UnsupportedError('Use demo mode on Web.');
