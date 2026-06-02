import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/music_provider.dart';
import '../screens/player_page.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final int index;

  const SongTile({super.key, required this.song, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isFav = music.isFavorite(song.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.music_note, color: Colors.white.withAlpha(179)),
      ),
      title: Text(
        song.title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(song.artist,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 8),
          Text(song.durationFormatted,
              style: const TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
      trailing: SizedBox(
        width: 72,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                  size: 20),
              color: isFav ? Colors.redAccent : Colors.white38,
              onPressed: () => music.toggleFavorite(song.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Colors.white24,
              onPressed: () => _confirmDelete(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
          ],
        ),
      ),
      onTap: () {
        final music = context.read<MusicProvider>();
        // Stage 1: set up the queue synchronously so the player page
        // knows what song to display before the file opens.
        context.read<PlayerProvider>().prepareSong(song, queue: music.songs);
        // Navigate immediately — the player page will load the file.
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
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a4e),
        title: const Text('删除歌曲', style: TextStyle(color: Colors.white)),
        content: Text('确定要删除"${song.title}"吗？\n这将同时删除本地文件。',
            style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<MusicProvider>().deleteSong(song.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
