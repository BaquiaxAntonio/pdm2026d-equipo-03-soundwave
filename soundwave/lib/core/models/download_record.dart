enum DownloadState { queued, downloading, completed, failed, pendingDeletion }

/// Persistent download metadata. Audio bytes are stored separately on disk.
class DownloadRecord {
  const DownloadRecord({
    required this.songId,
    required this.state,
    required this.bytesReceived,
    required this.createdAt,
    required this.updatedAt,
    this.totalBytes,
    this.localPath,
    this.errorMessage,
    this.deletionDeadline,
  }) : assert(bytesReceived >= 0),
       assert(totalBytes == null || totalBytes >= 0);

  final String songId;
  final DownloadState state;
  final int bytesReceived;
  final int? totalBytes;

  /// Path relative to the app's private audio directory.
  final String? localPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorMessage;
  final DateTime? deletionDeadline;

  double? get progress {
    final total = totalBytes;
    if (total == null || total == 0) return null;
    return (bytesReceived / total).clamp(0.0, 1.0).toDouble();
  }

  Map<String, Object?> toMap() => {
    'song_id': songId,
    'state': state.name,
    'bytes_received': bytesReceived,
    'total_bytes': totalBytes,
    'local_path': localPath,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'error_message': errorMessage,
    'deletion_deadline': deletionDeadline?.millisecondsSinceEpoch,
  };

  factory DownloadRecord.fromMap(Map<String, Object?> map) => DownloadRecord(
    songId: map['song_id']! as String,
    state: DownloadState.values.byName(map['state']! as String),
    bytesReceived: map['bytes_received']! as int,
    totalBytes: map['total_bytes'] as int?,
    localPath: map['local_path'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
    errorMessage: map['error_message'] as String?,
    deletionDeadline: map['deletion_deadline'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['deletion_deadline']! as int),
  );
}
