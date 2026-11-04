import 'dart:io';
import 'dart:typed_data';

/// Validate the container before publishing a download. The native decoder
/// remains responsible for codec decoding; HTML/error responses never qualify.
Future<bool> isValidAudioFile(File file) async {
  if (!await file.exists() || await file.length() < 46) return false;
  final handle = await file.open();
  try {
    final header = await handle.read(12);
    await handle.setPosition(0);
    if (_tag(header, 0, 4) == 'OggS') {
      return await _validOgg(handle, await file.length());
    }
    if (_tag(header, 0, 4) == 'RIFF' && _tag(header, 8, 12) == 'WAVE') {
      return await _validWav(handle, await file.length());
    }
    return false;
  } finally {
    await handle.close();
  }
}

String _tag(List<int> bytes, int start, int end) =>
    String.fromCharCodes(bytes.sublist(start, end));

Future<String> audioFileExtension(File file) async {
  final handle = await file.open();
  try {
    return _tag(await handle.read(4), 0, 4) == 'OggS' ? 'ogg' : 'wav';
  } finally {
    await handle.close();
  }
}

Future<bool> _validWav(RandomAccessFile file, int length) async {
  final header = ByteData.sublistView(await file.read(12));
  if (header.getUint32(4, Endian.little) + 8 != length) return false;
  var position = 12;
  var blockAlign = 0;
  var hasData = false;
  while (position + 8 <= length) {
    await file.setPosition(position);
    final chunk = await file.read(8);
    final size = ByteData.sublistView(chunk).getUint32(4, Endian.little);
    if (position + 8 + size > length) return false;
    final tag = _tag(chunk, 0, 4);
    if (tag == 'fmt ') {
      if (size < 16) return false;
      final data = ByteData.sublistView(await file.read(16));
      final channels = data.getUint16(2, Endian.little);
      final rate = data.getUint32(4, Endian.little);
      final bits = data.getUint16(14, Endian.little);
      blockAlign = data.getUint16(12, Endian.little);
      if (data.getUint16(0, Endian.little) != 1 ||
          channels == 0 ||
          rate == 0 ||
          ![8, 16, 24, 32].contains(bits) ||
          blockAlign != channels * bits ~/ 8 ||
          data.getUint32(8, Endian.little) != rate * blockAlign) {
        return false;
      }
    } else if (tag == 'data') {
      if (blockAlign == 0 || size == 0 || size % blockAlign != 0) return false;
      hasData = true;
    }
    position += 8 + size + size % 2;
  }
  return position == length && hasData;
}

Future<bool> _validOgg(RandomAccessFile file, int length) async {
  var position = 0;
  var first = true;
  var ended = false;
  while (position + 27 <= length) {
    await file.setPosition(position);
    final header = await file.read(27);
    if (_tag(header, 0, 4) != 'OggS' || header[4] != 0) return false;
    final segments = header[26];
    final table = await file.read(segments);
    if (table.length != segments) return false;
    final size = table.fold<int>(0, (a, b) => a + b);
    final end = position + 27 + segments + size;
    if (end > length || size == 0) return false;
    if (first) {
      if (header[5] & 2 == 0 || size < 8) return false;
      final packet = await file.read(8);
      if (!(_tag(packet, 0, 8) == 'OpusHead' ||
          (packet[0] == 1 && _tag(packet, 1, 7) == 'vorbis'))) {
        return false;
      }
      first = false;
    }
    ended = header[5] & 4 != 0;
    position = end;
  }
  return !first && ended && position == length;
}
