class Playlist {
  final String id;
  final String userId;
  final String name;
  final List<String> songIds;

  Playlist({
    required this.id,
    required this.userId,
    required this.name,
    this.songIds = const [],
  });

  Playlist copyWith({List<String>? songIds}) => Playlist(
        id: id,
        userId: userId,
        name: name,
        songIds: songIds ?? this.songIds,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
      };
}
