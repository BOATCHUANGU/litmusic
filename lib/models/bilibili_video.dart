class BilibiliVideo {
  final String bvid;
  final int avid;
  final int cid;
  final String title;
  final String coverUrl;
  final String ownerName;
  final int durationSeconds;

  BilibiliVideo({
    required this.bvid,
    required this.avid,
    required this.cid,
    required this.title,
    required this.coverUrl,
    required this.ownerName,
    required this.durationSeconds,
  });

  String get durationFormatted {
    if (durationSeconds <= 0) return '--:--';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory BilibiliVideo.fromJson(Map<String, dynamic> json) {
    return BilibiliVideo(
      bvid: json['bvid'] as String? ?? '',
      avid: json['id'] as int? ?? 0,
      cid: json['cid'] as int? ?? 0,
      title: json['title'] as String? ?? '未知标题',
      coverUrl: json['cover'] as String? ?? '',
      ownerName: (json['owner'] is Map)
          ? (json['owner']['name'] as String? ?? '未知UP主')
          : '未知UP主',
      durationSeconds: json['duration'] as int? ?? 0,
    );
  }

  /// Extract video info from the fav/res/list API response item
  factory BilibiliVideo.fromFavItem(Map<String, dynamic> json) {
    // The fav list API nests video info differently
    final duration = json['duration'] as int? ?? 0;

    // Parse duration string like "03:45" if integer not available
    int durationFromString(String s) {
      final parts = s.split(':');
      if (parts.length == 2) {
        return int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;
      }
      return 0;
    }

    return BilibiliVideo(
      bvid: json['bvid'] as String? ?? '',
      avid: json['id'] as int? ?? 0,
      cid: json['cid'] as int? ?? 0,
      title: json['title'] as String? ?? '未知标题',
      coverUrl: json['cover'] as String? ?? '',
      ownerName: (json['owner'] is Map)
          ? (json['owner']['name'] as String? ?? '未知UP主')
          : (json['upper'] is Map)
              ? (json['upper']['name'] as String? ?? '未知UP主')
              : '未知UP主',
      durationSeconds: duration > 0 ? duration : durationFromString(json['duration'] as String? ?? '0:00'),
    );
  }
}
