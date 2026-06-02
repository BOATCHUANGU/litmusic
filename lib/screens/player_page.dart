import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/music_provider.dart';
import '../providers/playlist_provider.dart';
import '../models/song.dart';
import 'create_playlist_page.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool _startedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_startedLoad) {
      _startedLoad = true;
      // Let the page render + event loop settle before we hit the
      // FFI-heavy setFilePath, so the loading spinner is visible.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          context.read<PlayerProvider>().loadCurrentSong();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    Widget body;
    if (player.isLoading) {
      body = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text('加载中…', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    } else if (player.error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(player.error!,
                style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    } else if (player.currentSong != null) {
      body = _PlayerBody(song: player.currentSong!);
    } else {
      body = const Center(
        child: Text('未选择歌曲',
            style: TextStyle(color: Colors.white38, fontSize: 18)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('正在播放', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: body,
    );
  }
}

class _PlayerBody extends StatelessWidget {
  final Song song;
  const _PlayerBody({required this.song});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child:
                  Icon(Icons.music_note, size: 100, color: colorScheme.primary),
            ),
            const SizedBox(height: 40),
            Text(
              song.title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              song.artist,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 32),
            const _SeekBar(),
            const SizedBox(height: 24),
            const _PlaybackControls(),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _FavoriteButton(song: song),
                _AddToPlaylistButton(song: song),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ==================== Seek Bar ====================

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  PlayerProvider? _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newPlayer = context.read<PlayerProvider>();
    if (_player != newPlayer) {
      _player?.removeListener(_onTick);
      _player = newPlayer;
      _player!.addListener(_onTick);
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player!;
    final position = player.position;
    final duration = player.duration ?? Duration.zero;
    final posSec = position.inSeconds;
    final durSec = duration.inSeconds == 0 ? 1 : duration.inSeconds;
    final fraction = posSec / durSec;

    final primary = Theme.of(context).colorScheme.primary;

    return RepaintBoundary(
      child: ExcludeSemantics(
        child: Column(
          children: [
            // Tap-to-seek bar — avoids Slider which is heavy on Windows
            // accessibility bridge.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final box = context.findRenderObject() as RenderBox;
                final barW = box.size.width;
                if (barW > 0) {
                  final sec = (d.localPosition.dx / barW * durSec)
                      .round()
                      .clamp(0, durSec);
                  player.seekTo(Duration(seconds: sec));
                }
              },
              onHorizontalDragUpdate: (d) {
                final box = context.findRenderObject() as RenderBox;
                final barW = box.size.width;
                if (barW > 0) {
                  final sec = (d.localPosition.dx / barW * durSec)
                      .round()
                      .clamp(0, durSec);
                  player.seekTo(Duration(seconds: sec));
                }
              },
              child: Container(
                height: 16, // generous touch target
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        children: [
                          Container(
                            height: 3,
                            color: Colors.white12,
                          ),
                          FractionallySizedBox(
                            widthFactor: fraction.clamp(0.0, 1.0),
                            child: Container(height: 3, color: primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(position),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
                Text(_fmt(duration),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ==================== Playback Controls ====================

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: () => player.setPlayMode(player.nextPlayMode),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.repeat, color: Colors.white38, size: 22),
              const SizedBox(height: 2),
              Text(player.playModeLabel,
                  style: const TextStyle(color: Colors.white38, fontSize: 8)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 40),
          color: Colors.white,
          onPressed: () => player.playPrevious(),
        ),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              player.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 36,
            ),
            color: Colors.white,
            onPressed: () => player.playOrPause(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 40),
          color: Colors.white,
          onPressed: () => player.playNext(),
        ),
        const Icon(Icons.volume_up, color: Colors.white38, size: 22),
      ],
    );
  }
}

// ==================== Favorite Button ====================

class _FavoriteButton extends StatelessWidget {
  final Song song;
  const _FavoriteButton({required this.song});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isFav = music.isFavorite(song.id);
    return IconButton(
      icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 28),
      color: isFav ? Colors.redAccent : Colors.white38,
      onPressed: () => music.toggleFavorite(song.id),
    );
  }
}

// ==================== Add to Playlist ====================

class _AddToPlaylistButton extends StatelessWidget {
  final Song song;
  const _AddToPlaylistButton({required this.song});

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>().playlists;
    return IconButton(
      icon: const Icon(Icons.playlist_add, size: 28),
      color: Colors.white38,
      onPressed: () {
        if (playlists.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先创建歌单')),
          );
          return;
        }
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1a1a2e),
          builder: (_) => _PlaylistPicker(song: song),
        );
      },
    );
  }
}

class _PlaylistPicker extends StatelessWidget {
  final Song song;
  const _PlaylistPicker({required this.song});

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>().playlists;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('添加到歌单',
                style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...playlists.map((pl) => ListTile(
                leading:
                    const Icon(Icons.playlist_play, color: Colors.white54),
                title: Text(pl.name, style: const TextStyle(color: Colors.white)),
                trailing: context
                        .watch<PlaylistProvider>()
                        .isSongInPlaylist(pl.id, song.id)
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  context
                      .read<PlaylistProvider>()
                      .addSongToPlaylist(pl.id, song.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加到"${pl.name}"')),
                  );
                },
              )),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.white54),
            title:
                const Text('创建新歌单', style: TextStyle(color: Colors.white54)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePlaylistPage()),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
