import 'dart:io';
import 'dart:typed_data';

/// Conservative PCM WAV validation until the API's supported formats are agreed.
/// Unknown formats fail closed instead of treating arbitrary bytes as audio.
Future<bool> isValidAudioFile(File file) async {
  if (!await file.exists() || await file.length() < 46) return false;
  final handle = await file.open();
  try {
    final bytes = await handle.read(44);
    final data = ByteData.sublistView(bytes);
    String tag(int start) =>
        String.fromCharCodes(bytes.sublist(start, start + 4));
    final length = await file.length();
    return tag(0) == 'RIFF' &&
        tag(8) == 'WAVE' &&
        tag(12) == 'fmt ' &&
        tag(36) == 'data' &&
        data.getUint32(4, Endian.little) + 8 == length &&
        data.getUint32(16, Endian.little) == 16 &&
        data.getUint16(20, Endian.little) == 1 &&
        data.getUint16(22, Endian.little) > 0 &&
        data.getUint32(24, Endian.little) > 0 &&
        [8, 16, 24, 32].contains(data.getUint16(34, Endian.little)) &&
        data.getUint16(32, Endian.little) ==
            data.getUint16(22, Endian.little) *
                data.getUint16(34, Endian.little) ~/
                8 &&
        data.getUint32(28, Endian.little) ==
            data.getUint32(24, Endian.little) *
                data.getUint16(32, Endian.little) &&
        (length - 44) % data.getUint16(32, Endian.little) == 0 &&
        data.getUint32(40, Endian.little) == length - 44;
  } finally {
    await handle.close();
  }
}
