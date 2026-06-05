class BilibiliFavFolder {
  final int mediaId;
  final String title;
  final int mediaCount;

  BilibiliFavFolder({
    required this.mediaId,
    required this.title,
    required this.mediaCount,
  });

  factory BilibiliFavFolder.fromJson(Map<String, dynamic> json) {
    return BilibiliFavFolder(
      mediaId: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '默认收藏夹',
      mediaCount: json['media_count'] as int? ?? 0,
    );
  }
}
