/// Canonical song metadata shared by catalog, downloads, and playback.
///
/// [id] is an app-wide stable ID. [provider] and [sourceId] retain the
/// provider identity; expiring audio URLs must never be used as song IDs.
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.provider,
    required this.sourceId,
    this.durationMs,
    this.artworkUrl,
  }) : assert(id != ''),
       assert(title != ''),
       assert(artist != ''),
       assert(provider != ''),
       assert(sourceId != ''),
       assert(durationMs == null || durationMs >= 0);

  final String id;
  final String title;
  final String artist;
  final int? durationMs;
  final String provider;
  final String sourceId;
  final Uri? artworkUrl;

  String get formattedDuration {
    final milliseconds = durationMs;
    if (milliseconds == null) return '--:--';
    final seconds = milliseconds ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'duration_ms': durationMs,
    'provider': provider,
    'source_id': sourceId,
    'artwork_url': artworkUrl?.toString(),
  };

  factory Song.fromMap(Map<String, Object?> map) => Song(
    id: map['id']! as String,
    title: map['title']! as String,
    artist: map['artist']! as String,
    durationMs: map['duration_ms'] as int?,
    provider: map['provider']! as String,
    sourceId: map['source_id']! as String,
    artworkUrl: map['artwork_url'] == null
        ? null
        : Uri.tryParse(map['artwork_url']! as String),
  );
}
