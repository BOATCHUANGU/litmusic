import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../models/playlist.dart';
import 'playlist_detail_page.dart';
import 'create_playlist_page.dart';

class PlaylistListPage extends StatelessWidget {
  const PlaylistListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>().playlists;

    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_play, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            Text('还没有创建歌单',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            Text('点击右下角按钮创建',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: playlists.length,
          itemBuilder: (_, i) => _PlaylistCard(playlist: playlists[i]),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreatePlaylistPage()),
              );
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.playlist_play, color: Colors.white54),
        ),
        title: Text(playlist.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text('${playlist.songIds.length} 首歌曲',
            style: const TextStyle(color: Colors.white38)),
        trailing: PopupMenuButton<String>(
          color: const Color(0xFF2a2a4e),
          icon: const Icon(Icons.more_vert, color: Colors.white38),
          onSelected: (value) {
            if (value == 'delete') {
              context
                  .read<PlaylistProvider>()
                  .deletePlaylist(playlist.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'delete',
                child: Text('删除歌单',
                    style: TextStyle(color: Colors.redAccent))),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PlaylistDetailPage(playlistId: playlist.id)),
          );
        },
      ),
    );
  }
}
