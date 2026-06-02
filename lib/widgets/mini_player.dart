import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/player_page.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    // Only rebuild when this route is frontmost — avoids flooding the
    // accessibility bridge on Windows while the full PlayerPage is open.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return _buildStatic(context);
    }

    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
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
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            // Song thumbnail placeholder
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.music_note, color: Colors.white54, size: 28),
            ),
            // Song info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Play/Pause button
            IconButton(
              icon: Icon(
                player.isPlaying ? Icons.pause : Icons.play_arrow,
                color: colorScheme.primary,
              ),
              onPressed: () => player.playOrPause(),
            ),
            // Progress indicator (uses throttled position from provider)
            _ProgressBar(
              position: player.position,
              duration: player.duration,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// Static snapshot — shown when this route is in the background,
  /// so we don't subscribe to position updates that would stress
  /// the accessibility bridge on Windows.
  Widget _buildStatic(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
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
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.music_note, color: Colors.white54, size: 28),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.artist,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                player.isPlaying ? Icons.pause : Icons.play_arrow,
                color: colorScheme.primary,
              ),
              onPressed: () => player.playOrPause(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final Duration position;
  final Duration? duration;
  final Color color;
  const _ProgressBar({
    required this.position,
    this.duration,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dur = duration ?? Duration.zero;
    final progress =
        dur.inSeconds == 0 ? 0.0 : position.inSeconds / dur.inSeconds;
    return Container(
      width: 2,
      height: 32,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(1),
      ),
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: progress,
        child: Container(
          width: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
