import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/contracts/audio_file_store.dart';
import '../../../core/errors/repository_exception.dart';

/// The caller supplies a private app directory; no platform plugin in widgets.
class LocalAudioFileStore implements AudioFileStore {
  LocalAudioFileStore(Directory directory)
    : root = Directory(p.normalize(directory.absolute.path));

  final Directory root;

  String _key(String id) =>
      base64Url.encode(utf8.encode(id)).replaceAll('=', '');

  @override
  String resolve(String relativePath) {
    final resolved = p.normalize(p.join(root.path, relativePath));
    if (p.isAbsolute(relativePath) || !p.isWithin(root.path, resolved)) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidData,
        'Audio path must stay inside the private directory.',
      );
    }
    return resolved;
  }

  @override
  Future<String> createTemporaryPath(String songId) async {
    final directory = await Directory(
      resolve('.part/${_key(songId)}'),
    ).create(recursive: true);
    final temporary = await directory.createTemp('transfer-');
    final file = await File(p.join(temporary.path, 'audio.part')).create();
    return file.path;
  }

  @override
  Future<String> commit(String temporaryPath, String songId) async {
    final source = p.normalize(p.absolute(temporaryPath));
    if (!p.isWithin(resolve('.part/${_key(songId)}'), source)) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidData,
        'Temporary file does not belong to this song.',
      );
    }
    final file = File(source);
    if (!await file.exists() || await file.length() == 0) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidData,
        'Audio file is missing or empty.',
      );
    }
    // Unique names avoid replacing a previously committed file on a retry.
    final relative =
        'audio/${_key(songId)}/${p.basename(p.dirname(source))}.audio';
    final target = File(resolve(relative));
    await target.parent.create(recursive: true);
    await file.rename(target.path);
    return relative;
  }

  @override
  Future<bool> exists(String relativePath) =>
      File(resolve(relativePath)).exists();

  @override
  Future<void> delete(String relativePath) async {
    final file = File(resolve(relativePath));
    if (await file.exists()) await file.delete();
  }
}
