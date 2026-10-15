/// Registro local de una descarga simulada; no representa un archivo real.
class DownloadStatus {
  const DownloadStatus({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    required this.sizeMb,
    required this.coverIndex,
  });

  final String id;
  final String title;
  final String artist;
  final int durationSeconds;
  final double sizeMb;
  final int coverIndex;

  // En esta fase solo se muestran descargas completadas.
  bool get isDownloaded => true;

  String get durationLabel =>
      '${durationSeconds ~/ 60}:${(durationSeconds % 60).toString().padLeft(2, '0')}';
}
