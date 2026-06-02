import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';
import 'player_page.dart';

class PlaylistDetailPage extends StatelessWidget {
  final String playlistId;
  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final playlist = context.watch<PlaylistProvider>().getPlaylistById(playlistId);
    if (playlist == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
            backgroundColor: const Color(0xFF1a1a2e),
            title: const Text('歌单', style: TextStyle(color: Colors.white))),
        body: const Center(
            child: Text('歌单不存在', style: TextStyle(color: Colors.white38))),
      );
    }

    final music = context.read<MusicProvider>();
    final songs = playlist.songIds
        .map((id) => music.getSongById(id))
        .where((s) => s != null)
        .map((s) => s!)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              tooltip: '播放全部',
              onPressed: () {
                context.read<PlayerProvider>().prepareSong(
                    songs.first, queue: songs);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const PlayerPage(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white54),
            tooltip: '添加歌曲',
            onPressed: () => _showAddSongSheet(context, playlistId),
          ),
        ],
      ),
      body: songs.isEmpty
          ? const Center(
              child: Text('歌单是空的',
                  style: TextStyle(color: Colors.white38, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: songs.length,
              itemBuilder: (_, i) => SongTile(song: songs[i], index: i),
            ),
    );
  }

  void _showAddSongSheet(BuildContext context, String playlistId) {
    final allSongs = context.read<MusicProvider>().songs;
    final playlistProvider = context.read<PlaylistProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('从歌曲库选择',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            if (allSongs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('还没有导入歌曲',
                    style: TextStyle(color: Colors.white38)),
              )
            else
              ...allSongs.map((song) => ListTile(
                    leading: const Icon(Icons.music_note, color: Colors.white54),
                    title: Text(song.title,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(song.artist,
                        style: const TextStyle(color: Colors.white38)),
                    trailing: playlistProvider.isSongInPlaylist(
                            playlistId, song.id)
                        ? const Icon(Icons.check, color: Colors.green)
                        : IconButton(
                            icon: const Icon(Icons.add, color: Colors.white38),
                            onPressed: () {
                              playlistProvider.addSongToPlaylist(
                                  playlistId, song.id);
                            },
                          ),
                  )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
