import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/music_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/song_tile.dart';
import '../widgets/mini_player.dart';
import 'playlist_list_page.dart';
import 'my_tab.dart';
import 'welcome_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final music = context.read<MusicProvider>();
    final playlist = context.read<PlaylistProvider>();
    await music.loadSongs();
    if (auth.currentUserId != null) {
      await music.loadFavorites(auth.currentUserId!);
      await playlist.loadPlaylists(auth.currentUserId!);
    }
  }

  void _importMusic() async {
    final music = context.read<MusicProvider>();
    final msg = await music.importMusicFiles();
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  void _logout() {
    context.read<AuthProvider>().logout();
    context.read<PlaylistProvider>().clearAndNotify();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
            ['我的音乐', '我的收藏', '我的歌单', '我的'][_currentTab]),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          if (_currentTab == 0)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: '导入本地音乐',
              onPressed: _importMusic,
              color: Colors.white,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: _logout,
            color: Colors.white54,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                const _AllSongsTab(),
                const _FavoritesTab(),
                const PlaylistListPage(),
                const MyTab(),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        backgroundColor: const Color(0xFF1a1a2e),
        indicatorColor: colorScheme.primary.withAlpha(50),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.music_note),
              selectedIcon: Icon(Icons.music_note, color: Colors.deepPurple),
              label: '歌曲'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite, color: Colors.deepPurple),
              label: '收藏'),
          NavigationDestination(
              icon: Icon(Icons.playlist_play),
              selectedIcon: Icon(Icons.playlist_play, color: Colors.deepPurple),
              label: '歌单'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Colors.deepPurple),
              label: '我的'),
        ],
      ),
    );
  }
}

// ==================== All Songs Tab ====================

class _AllSongsTab extends StatelessWidget {
  const _AllSongsTab();

  @override
  Widget build(BuildContext context) {
    final songs = context.watch<MusicProvider>().songs;
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('还没有导入歌曲',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('点击右上角图标导入本地音乐',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: songs.length,
      itemBuilder: (_, i) => SongTile(song: songs[i], index: i),
    );
  }
}

// ==================== Favorites Tab ====================

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final favorites = music.favoriteSongs;
    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('还没有收藏歌曲',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('在歌曲列表中点击心形图标收藏',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: favorites.length,
      itemBuilder: (_, i) => SongTile(song: favorites[i], index: i),
    );
  }
}
