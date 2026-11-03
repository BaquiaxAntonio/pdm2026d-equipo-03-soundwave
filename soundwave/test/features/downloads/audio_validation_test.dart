import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/downloads/data/audio_validation.dart';
import 'audio_fixture.dart';

void main() {
  test(
    'acepta WAV PCM con bloques RIFF adicionales y rechaza truncado',
    () async {
      final directory = await Directory.systemTemp.createTemp('soundwave-wav-');
      try {
        final original = wavFixture();
        final bytes = Uint8List.fromList([
          ...original.take(36),
          ...'LIST'.codeUnits,
          4,
          0,
          0,
          0,
          ...'INFO'.codeUnits,
          ...original.skip(36),
        ]);
        ByteData.sublistView(
          bytes,
        ).setUint32(4, bytes.length - 8, Endian.little);
        final file = File('${directory.path}/audio.part');
        await file.writeAsBytes(bytes);
        expect(await isValidAudioFile(file), isTrue);
        expect(await audioFileExtension(file), 'wav');
        await file.writeAsBytes(bytes.sublist(0, bytes.length - 1));
        expect(await isValidAudioFile(file), isFalse);
        await file.writeAsString('<html>not an audio file</html>');
        expect(await isValidAudioFile(file), isFalse);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
