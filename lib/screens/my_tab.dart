import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bilibili_provider.dart';
import '../models/bilibili_fav_folder.dart';
import '../widgets/bilibili_video_tile.dart';
import 'bilibili_login_page.dart';

class MyTab extends StatefulWidget {
  const MyTab({super.key});

  @override
  State<MyTab> createState() => _MyTabState();
}

class _MyTabState extends State<MyTab> {
  final Set<String> _selectedBvids = {};
  bool _selectionMode = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final bili = context.read<BilibiliProvider>();
      if (bili.hasMore && !bili.isLoadingFavorites) {
        bili.loadMoreFavorites();
      }
    }
  }

  void _toggleSelection(String bvid) {
    setState(() {
      if (_selectedBvids.contains(bvid)) {
        _selectedBvids.remove(bvid);
        if (_selectedBvids.isEmpty) _selectionMode = false;
      } else {
        _selectedBvids.add(bvid);
      }
    });
  }

  void _enterSelectionMode(String bvid) {
    setState(() {
      _selectionMode = true;
      _selectedBvids.add(bvid);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedBvids.clear();
    });
  }

  Future<void> _downloadSelected() async {
    if (_selectedBvids.isEmpty) return;
    final bili = context.read<BilibiliProvider>();
    final videos = bili.favorites
        .where((v) =>
            _selectedBvids.contains(v.bvid) &&
            !bili.isDownloaded(v.bvid) &&
            !bili.isDownloading(v.bvid))
        .toList();

    if (videos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选中的视频已全部下载或正在下载中')),
        );
      }
      return;
    }

    final count = await bili.downloadSelected(videos);
    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功下载 $count / ${videos.length} 个视频音频')),
      );
    }
  }

  void _openLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BilibiliLoginPage()),
    );
    if (result == true && mounted) {
      // After successful login, auto-load favorites
      final bili = context.read<BilibiliProvider>();
      if (bili.isLoggedIn) {
        await bili.loadFavFolders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bili = context.watch<BilibiliProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // Error banner
    if (bili.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && bili.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(bili.error!),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }

    return Stack(
      children: [
        // Not logged in
        if (!bili.isLoggedIn) _buildNotLoggedIn(colorScheme),

        // Logged in — show folders or favorites
        if (bili.isLoggedIn && bili.currentFolder == null)
          _buildFolderList(bili, colorScheme),

        // Viewing a folder's favorites
        if (bili.isLoggedIn && bili.currentFolder != null)
          _buildFavoritesList(bili),

        // Selection mode FAB
        if (_selectionMode && _selectedBvids.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _downloadSelected,
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.download_rounded),
              label: Text('下载 ${_selectedBvids.length} 个'),
            ),
          ),

        // Exit selection button
        if (_selectionMode)
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton.small(
              onPressed: _exitSelectionMode,
              backgroundColor: Colors.white24,
              foregroundColor: Colors.white,
              child: const Icon(Icons.close),
            ),
          ),
      ],
    );
  }

  // ==================== NOT LOGGED IN ====================

  Widget _buildNotLoggedIn(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.cloud, size: 50, color: Colors.white24),
            ),
            const SizedBox(height: 24),
            const Text(
              '连接Bilibili',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '登录Bilibili账号后，可以查看收藏视频\n并将视频解析为纯音频保存至本地',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openLogin,
              icon: const Icon(Icons.login),
              label: const Text('Bilibili登录', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFB7299), // Bilibili pink
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FOLDER LIST ====================

  Widget _buildFolderList(
      BilibiliProvider bili, ColorScheme colorScheme) {
    if (bili.isLoadingFolders) {
      return Column(
        children: [
          _buildUserHeader(bili),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildUserHeader(bili),
        const Divider(color: Colors.white12, height: 1),
        if (bili.favFolders.isEmpty && !bili.isLoadingFolders)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_off, size: 60, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    '没有找到收藏夹',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => bili.loadFavFolders(),
                    icon: const Icon(Icons.refresh, color: Colors.white54),
                    label: const Text('重新加载',
                        style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 16),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Text(
                    '选择收藏夹',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
                ...bili.favFolders
                    .map((folder) => _buildFolderTile(folder, bili)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUserHeader(BilibiliProvider bili) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.white54, size: 20),
          const SizedBox(width: 8),
          Text(
            bili.bilibiliUname ?? 'B站用户',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => bili.logoutBilibili(),
            icon: const Icon(Icons.logout, size: 16, color: Colors.white38),
            label: const Text('退出登录',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTile(BilibiliFavFolder folder, BilibiliProvider bili) {
    return InkWell(
      onTap: () => bili.loadFavorites(folder.mediaId),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder, color: Colors.deepPurple, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${folder.mediaCount} 个视频',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  // ==================== FAVORITES LIST ====================

  Widget _buildFavoritesList(BilibiliProvider bili) {
    return Column(
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: const Color(0xFF1a1a2e),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => bili.backToFolders(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bili.currentFolder?.title ?? '收藏视频',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${bili.totalCount} 个视频',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_selectionMode)
                IconButton(
                  icon: const Icon(Icons.checklist, color: Colors.white54),
                  tooltip: '批量选择',
                  onPressed: () => setState(() => _selectionMode = true),
                ),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),

        // List
        Expanded(
          child: bili.isLoadingFavorites && bili.favorites.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                )
              : bili.favorites.isEmpty
                  ? const Center(
                      child: Text(
                        '收藏夹为空',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        if (bili.currentFolder != null) {
                          await bili.loadFavorites(bili.currentFolder!.mediaId);
                        }
                      },
                      color: Colors.deepPurple,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(
                            top: 8, bottom: 80),
                        itemCount:
                            bili.favorites.length + (bili.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= bili.favorites.length) {
                            // Loading indicator for pagination
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white54,
                                ),
                              ),
                            );
                          }

                          final video = bili.favorites[index];
                          return BilibiliVideoTile(
                            video: video,
                            isSelected:
                                _selectedBvids.contains(video.bvid),
                            selectionMode: _selectionMode,
                            onTap: _selectionMode
                                ? () => _toggleSelection(video.bvid)
                                : null,
                            onLongPress: !_selectionMode
                                ? () => _enterSelectionMode(video.bvid)
                                : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
