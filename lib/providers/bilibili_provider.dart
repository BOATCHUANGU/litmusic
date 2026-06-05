import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/song.dart';
import '../models/bilibili_video.dart';
import '../models/bilibili_fav_folder.dart';
import '../services/bilibili_api.dart';
import '../services/audio_downloader.dart';
import '../services/database_helper.dart';

class BilibiliProvider extends ChangeNotifier {
  final BilibiliApi _api = BilibiliApi();
  final DatabaseHelper _db = DatabaseHelper();

  // --- Login state ---
  bool _isLoggedIn = false;
  String? _bilibiliUname;
  int? _bilibiliUserId;

  // --- Favorites state ---
  List<BilibiliFavFolder> _favFolders = [];
  BilibiliFavFolder? _currentFolder;
  List<BilibiliVideo> _favorites = [];
  bool _isLoadingFavorites = false;
  bool _isLoadingFolders = false;
  String? _error;

  // --- Pagination ---
  int _currentPage = 1;
  bool _hasMore = false;
  int _totalCount = 0;

  // --- Download state ---
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadingBvids = {};
  final Set<String> _downloadedBvids = {};

  // --- Callback for refreshing music library ---
  VoidCallback? onSongAdded;

  // --- Getters ---
  bool get isLoggedIn => _isLoggedIn;
  String? get bilibiliUname => _bilibiliUname;
  int? get bilibiliUserId => _bilibiliUserId;
  List<BilibiliFavFolder> get favFolders => _favFolders;
  BilibiliFavFolder? get currentFolder => _currentFolder;
  List<BilibiliVideo> get favorites => _favorites;
  bool get isLoadingFavorites => _isLoadingFavorites;
  bool get isLoadingFolders => _isLoadingFolders;
  String? get error => _error;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;

  double getDownloadProgress(String bvid) => _downloadProgress[bvid] ?? 0.0;
  bool isDownloading(String bvid) => _downloadingBvids.contains(bvid);
  bool isDownloaded(String bvid) => _downloadedBvids.contains(bvid);

  // ==================== Session ====================

  /// Check for existing Bilibili session on app start
  Future<void> checkSession() async {
    final hasSession = await _api.hasSession();
    if (hasSession) {
      final userInfo = await _api.getUserInfo();
      if (userInfo != null) {
        _isLoggedIn = true;
        _bilibiliUname = userInfo['uname'] as String?;
        _bilibiliUserId = userInfo['mid'] as int?;
        notifyListeners();
      } else {
        await _api.clearSession();
      }
    }
  }

  /// Called after WebView login captures cookies successfully
  Future<void> onWebViewLoginSuccess({
    required String sessdata,
    required String biliJct,
    required String dedeUserId,
    String? dedeUserIdCkMd5,
    String? sid,
  }) async {
    await _api.saveCookies(
      sessdata: sessdata,
      biliJct: biliJct,
      dedeUserId: dedeUserId,
      dedeUserIdCkMd5: dedeUserIdCkMd5,
      sid: sid,
    );

    final userInfo = await _api.getUserInfo();
    if (userInfo != null) {
      _isLoggedIn = true;
      _bilibiliUname = userInfo['uname'] as String?;
      _bilibiliUserId = userInfo['mid'] as int?;
      _error = null;
      notifyListeners();
    }
  }

  /// Logout from Bilibili
  Future<void> logoutBilibili() async {
    await _api.clearSession();
    _isLoggedIn = false;
    _bilibiliUname = null;
    _bilibiliUserId = null;
    _favFolders = [];
    _currentFolder = null;
    _favorites = [];
    _downloadProgress.clear();
    _downloadingBvids.clear();
    _downloadedBvids.clear();
    _error = null;
    notifyListeners();
  }

  // ==================== Favorites ====================

  /// Load all favorite folders (created + collected + default)
  Future<void> loadFavFolders() async {
    if (_bilibiliUserId == null) return;
    _isLoadingFolders = true;
    _error = null;
    notifyListeners();

    try {
      _favFolders = await _api.getAllFolders(_bilibiliUserId!);
      if (_favFolders.isEmpty) {
        _error = '未找到任何收藏夹';
      }
    } catch (e) {
      _error = '加载收藏夹失败: $e';
    }

    _isLoadingFolders = false;
    notifyListeners();
  }

  /// Load favorites from a specific folder.
  /// For the default folder (mediaId == userId), falls back to user-space
  /// favorites API if the folder-based API returns empty.
  Future<void> loadFavorites(int mediaId) async {
    _isLoadingFavorites = true;
    _error = null;
    _currentPage = 1;
    _favorites = [];
    notifyListeners();

    try {
      // Try folder-based API first
      Map<String, dynamic>? result;
      bool usedFallback = false;

      try {
        result = await _api.getFavVideos(mediaId, page: 1);
      } on BilibiliApiException catch (e) {
        // If folder API fails and this is the default folder (mediaId == userId),
        // fall back to the user-space favorites endpoint
        if (_bilibiliUserId != null &&
            (mediaId == _bilibiliUserId || e.code == -400)) {
          result = await _api.getFavVideosByUser(_bilibiliUserId!, page: 1);
          usedFallback = true;
        } else {
          rethrow;
        }
      }

      if (result != null) {
        _favorites = (result['videos'] as List<BilibiliVideo>?) ?? [];
        _hasMore = result['has_more'] as bool? ?? false;
        _totalCount = result['total'] as int? ?? _favorites.length;

        if (usedFallback) {
          // We're using the all-favorites endpoint; wrap it as a folder
          _currentFolder = BilibiliFavFolder(
            mediaId: mediaId,
            title: '全部收藏',
            mediaCount: _totalCount,
          );
        } else {
          _currentFolder = _favFolders.firstWhere(
            (f) => f.mediaId == mediaId,
            orElse: () => BilibiliFavFolder(
              mediaId: mediaId,
              title: '收藏夹',
              mediaCount: _totalCount,
            ),
          );
        }
      } else {
        _error = '加载收藏视频失败：服务器返回空数据';
      }
    } on BilibiliApiException catch (e) {
      if (e.code == -101) {
        await logoutBilibili();
        _error = '登录已过期，请重新登录';
      } else {
        _error = '${e.message} (code: ${e.code})';
      }
    } catch (e) {
      _error = '加载失败: $e';
    }

    _isLoadingFavorites = false;
    notifyListeners();
  }

  /// Load next page of favorites
  Future<void> loadMoreFavorites() async {
    if (!_hasMore || _isLoadingFavorites || _currentFolder == null) return;

    _isLoadingFavorites = true;
    notifyListeners();

    try {
      _currentPage++;
      final result = await _api.getFavVideos(
        _currentFolder!.mediaId,
        page: _currentPage,
      );
      if (result != null) {
        final newVideos = (result['videos'] as List<BilibiliVideo>?) ?? [];
        _favorites.addAll(newVideos);
        _hasMore = result['has_more'] as bool? ?? false;
      }
    } catch (e) {
      _currentPage--;
      _error = '加载更多失败: $e';
    }

    _isLoadingFavorites = false;
    notifyListeners();
  }

  /// Go back to folder selection
  void backToFolders() {
    _currentFolder = null;
    _favorites = [];
    _error = null;
    notifyListeners();
  }

  // ==================== Download ====================

  /// Download a single video's audio and add to local library
  Future<bool> downloadAudio(BilibiliVideo video) async {
    if (_downloadingBvids.contains(video.bvid)) return false;

    _downloadingBvids.add(video.bvid);
    _downloadProgress[video.bvid] = 0.0;
    notifyListeners();

    try {
      // Step 1: Get audio URL (getAudioUrl will auto-resolve cid if 0)
      final audioUrl = await _api.getAudioUrl(video.bvid, video.cid);
      if (audioUrl == null || audioUrl.isEmpty) {
        _error = '获取音频地址失败: ${video.title}';
        _downloadingBvids.remove(video.bvid);
        _downloadProgress.remove(video.bvid);
        notifyListeners();
        return false;
      }

      // Step 2: Download audio
      final filePath = await AudioDownloader.downloadAudio(
        url: audioUrl,
        fileName: video.title,
        ownerName: video.ownerName,
        durationSeconds: video.durationSeconds,
        onProgress: (received, total) {
          _downloadProgress[video.bvid] =
              total > 0 ? received / total : 0.0;
          notifyListeners();
        },
      );

      // Step 3: Create Song entry in database
      final song = Song(
        id: const Uuid().v4(),
        title: video.title,
        artist: video.ownerName,
        filePath: filePath,
        durationSeconds: video.durationSeconds,
        source: 'bilibili',
      );
      await _db.insertSongWithSource(song, 'bilibili');

      _downloadedBvids.add(video.bvid);
      _downloadingBvids.remove(video.bvid);
      _downloadProgress.remove(video.bvid);
      _error = null;

      onSongAdded?.call();
      notifyListeners();
      return true;
    } catch (e) {
      _error = '下载失败: ${video.title} — $e';
      _downloadingBvids.remove(video.bvid);
      _downloadProgress.remove(video.bvid);
      notifyListeners();
      return false;
    }
  }

  /// Download multiple selected videos sequentially
  Future<int> downloadSelected(List<BilibiliVideo> videos) async {
    int successCount = 0;
    for (final video in videos) {
      final success = await downloadAudio(video);
      if (success) successCount++;
    }
    return successCount;
  }
}
