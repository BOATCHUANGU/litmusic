class Song {
  final String id;
  final String title;
  final String artist;
  final String filePath;
  final int durationSeconds;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    required this.durationSeconds,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'file_path': filePath,
        'duration_seconds': durationSeconds,
      };

  factory Song.fromMap(Map<String, dynamic> map) => Song(
        id: map['id'] as String,
        title: map['title'] as String,
        artist: map['artist'] as String,
        filePath: map['file_path'] as String,
        durationSeconds: map['duration_seconds'] as int,
      );

  String get durationFormatted {
    if (durationSeconds <= 0) return '--:--';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
