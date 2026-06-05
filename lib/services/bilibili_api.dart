import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bilibili_video.dart';
import '../models/bilibili_fav_folder.dart';

class BilibiliApiException implements Exception {
  final int code;
  final String message;
  BilibiliApiException(this.code, this.message);

  @override
  String toString() => 'BilibiliApiException($code): $message';
}

class BilibiliApi {
  static final BilibiliApi _instance = BilibiliApi._internal();
  factory BilibiliApi() => _instance;
  BilibiliApi._internal();

  late final Dio _dio;
  bool _initialized = false;

  // Stored Bilibili auth cookies
  String? _sessdata;
  String? _biliJct;
  String? _dedeUserId;
  String? _dedeUserIdCkMd5;
  String? _sid;

  // Anonymous / fingerprint cookies
  String? _buvid3;
  String? _buvid4;

  String? get sessdata => _sessdata;
  String? get biliJct => _biliJct;
  String? get dedeUserId => _dedeUserId;

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  void _ensureInitialized() {
    if (_initialized) return;
    _dio = Dio(BaseOptions(
      headers: {
        'User-Agent': _userAgent,
        'Referer': 'https://www.bilibili.com',
        'Origin': 'https://www.bilibili.com',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _initialized = true;
  }

  /// Build Cookie header string from all stored cookies
  String? _buildCookieHeader() {
    final parts = <String>[];
    void add(String name, String? value) {
      if (value != null && value.isNotEmpty) parts.add('$name=$value');
    }

    add('SESSDATA', _sessdata);
    add('bili_jct', _biliJct);
    add('DedeUserID', _dedeUserId);
    add('DedeUserID__ckMd5', _dedeUserIdCkMd5);
    add('sid', _sid);
    add('buvid3', _buvid3);
    add('buvid4', _buvid4);

    return parts.isEmpty ? null : parts.join('; ');
  }

  /// Build standard request options with cookie header
  Options _buildOptions() {
    final cookie = _buildCookieHeader();
    return Options(headers: {
      'Cookie': ?cookie,
    });
  }

  /// Save Bilibili cookies to SharedPreferences
  Future<void> saveCookies({
    required String sessdata,
    required String biliJct,
    required String dedeUserId,
    String? dedeUserIdCkMd5,
    String? sid,
  }) async {
    _sessdata = sessdata;
    _biliJct = biliJct;
    _dedeUserId = dedeUserId;
    _dedeUserIdCkMd5 = dedeUserIdCkMd5;
    _sid = sid;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bili_sessdata', sessdata);
    await prefs.setString('bili_jct', biliJct);
    await prefs.setString('bili_dedeuserid', dedeUserId);
    if (dedeUserIdCkMd5 != null) {
      await prefs.setString('bili_dedeuserid_ckmd5', dedeUserIdCkMd5);
    }
    if (sid != null) {
      await prefs.setString('bili_sid', sid);
    }

    // Fetch anonymous cookies after saving auth cookies
    await _fetchAnonymousCookies();
  }

  /// Fetch anonymous/fingerprint cookies (buvid3, buvid4) from Bilibili
  Future<void> _fetchAnonymousCookies() async {
    try {
      final fingerDio = Dio(BaseOptions(
        headers: {'User-Agent': _userAgent},
        connectTimeout: const Duration(seconds: 10),
      ));
      final response = await fingerDio.get(
        'https://api.bilibili.com/x/frontend/finger/spi',
        queryParameters: {'spi_prevention': '1'},
      );
      final data = response.data;
      if (data['code'] == 0 && data['data'] != null) {
        _buvid3 = data['data']['b_3'] as String?;
        _buvid4 = data['data']['b_4'] as String?;

        final prefs = await SharedPreferences.getInstance();
        if (_buvid3 != null) {
          await prefs.setString('bili_buvid3', _buvid3!);
        }
        if (_buvid4 != null) {
          await prefs.setString('bili_buvid4', _buvid4!);
        }
      }
    } catch (_) {
      // Anonymous cookies are optional; continue without them
    }
  }

  /// Load stored Bilibili cookies from SharedPreferences
  Future<bool> loadCookies() async {
    final prefs = await SharedPreferences.getInstance();
    _sessdata = prefs.getString('bili_sessdata');
    _biliJct = prefs.getString('bili_jct');
    _dedeUserId = prefs.getString('bili_dedeuserid');
    _dedeUserIdCkMd5 = prefs.getString('bili_dedeuserid_ckmd5');
    _sid = prefs.getString('bili_sid');
    _buvid3 = prefs.getString('bili_buvid3');
    _buvid4 = prefs.getString('bili_buvid4');

    return _sessdata != null &&
        _sessdata!.isNotEmpty &&
        _biliJct != null &&
        _biliJct!.isNotEmpty;
  }

  /// Check if we have a valid Bilibili session
  Future<bool> hasSession() async {
    if (_sessdata == null || _sessdata!.isEmpty) {
      final loaded = await loadCookies();
      if (!loaded) return false;
    }
    return true;
  }

  /// Clear Bilibili session
  Future<void> clearSession() async {
    _sessdata = null;
    _biliJct = null;
    _dedeUserId = null;
    _dedeUserIdCkMd5 = null;
    _sid = null;
    _buvid3 = null;
    _buvid4 = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bili_sessdata');
    await prefs.remove('bili_jct');
    await prefs.remove('bili_dedeuserid');
    await prefs.remove('bili_dedeuserid_ckmd5');
    await prefs.remove('bili_sid');
    await prefs.remove('bili_buvid3');
    await prefs.remove('bili_buvid4');
    await prefs.remove('bili_username');
  }

  /// Get current user info from Bilibili
  /// Returns: { 'mid': int, 'uname': String } or null on failure
  Future<Map<String, dynamic>?> getUserInfo() async {
    _ensureInitialized();
    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/web-interface/nav',
        options: _buildOptions(),
      );
      final data = response.data;
      if (data['code'] == 0 && data['data'] != null) {
        return {
          'mid': data['data']['mid'],
          'uname': data['data']['uname'] as String? ?? '',
        };
      }
      return null;
    } on DioException {
      return null;
    }
  }

  /// Get user's created favorite folder list
  Future<List<BilibiliFavFolder>> getFavFolders(int userId) async {
    _ensureInitialized();
    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/v3/fav/folder/created/list-all',
        queryParameters: {
          'up_mid': userId,
          'platform': 'web',
        },
        options: _buildOptions(),
      );
      final data = response.data;
      if (data['code'] == 0 && data['data'] != null) {
        final list = data['data']['list'] as List? ?? [];
        return list
            .map((e) => BilibiliFavFolder.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException {
      return [];
    }
  }

  /// Get user's collected favorite folder list
  Future<List<BilibiliFavFolder>> getCollectedFolders(int userId) async {
    _ensureInitialized();
    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/v3/fav/folder/collected/list-all',
        queryParameters: {
          'up_mid': userId,
          'platform': 'web',
        },
        options: _buildOptions(),
      );
      final data = response.data;
      if (data['code'] == 0 && data['data'] != null) {
        final list = data['data']['list'] as List? ?? [];
        return list
            .map((e) => BilibiliFavFolder.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException {
      return [];
    }
  }

  /// Get all favorite folders (created + collected).
  /// The `list-all` endpoint returns all folders including the default one.
  Future<List<BilibiliFavFolder>> getAllFolders(int userId) async {
    final folders = <BilibiliFavFolder>[];

    // Get user-created folders (includes default favorites folder)
    final created = await getFavFolders(userId);
    folders.addAll(created);

    // Append collected folders (skip duplicates)
    final collected = await getCollectedFolders(userId);
    for (final f in collected) {
      if (folders.any((existing) => existing.mediaId == f.mediaId)) continue;
      folders.add(f);
    }

    return folders;
  }

  /// Get videos in a favorite folder (paginated).
  ///
  /// Returns a map with keys: 'videos', 'has_more', 'total'
  /// Throws BilibiliApiException on auth errors.
  /// Returns null on network errors.
  Future<Map<String, dynamic>?> getFavVideos(
    int mediaId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    _ensureInitialized();
    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/v3/fav/resource/list',
        queryParameters: {
          'media_id': mediaId,
          'pn': page,
          'ps': pageSize,
          'platform': 'web',
        },
        options: _buildOptions(),
      );
      final data = response.data;
      final code = data['code'] as int? ?? -1;

      if (code == -101) {
        throw BilibiliApiException(-101, '登录已过期，请重新登录Bilibili');
      }

      if (code == -400) {
        throw BilibiliApiException(-400, '请求错误，收藏夹可能为空或不存在');
      }

      if (code == 0 && data['data'] != null) {
        final result = data['data'];
        final medias = result['medias'] as List? ?? [];

        final videos = <BilibiliVideo>[];
        for (final item in medias) {
          final map = item as Map<String, dynamic>;
          final video = BilibiliVideo.fromFavItem(map);

          // If cid is 0, try to find it in the pages field
          if (video.cid == 0) {
            final pages = map['pages'] as List?;
            if (pages != null && pages.isNotEmpty) {
              final firstPage = pages[0] as Map<String, dynamic>;
              final cid = firstPage['cid'] as int? ?? 0;
              videos.add(BilibiliVideo(
                bvid: video.bvid,
                avid: video.avid,
                cid: cid,
                title: video.title,
                coverUrl: video.coverUrl,
                ownerName: video.ownerName,
                durationSeconds: video.durationSeconds,
              ));
              continue;
            }
          }
          videos.add(video);
        }

        final hasMore = result['has_more'] as bool? ?? false;

        return {
          'videos': videos,
          'has_more': hasMore,
          'total': result['info']?['media_count'] as int? ?? videos.length,
        };
      }

      if (code != 0) {
        throw BilibiliApiException(
            code, data['message'] as String? ?? '未知错误($code)');
      }

      return null;
    } on BilibiliApiException {
      rethrow;
    } on DioException catch (e) {
      throw BilibiliApiException(-2, '网络错误: ${e.message}');
    }
  }

  /// Fallback: Get user's favorite videos directly (not via folder).
  /// Uses the user-space favorites endpoint.
  Future<Map<String, dynamic>?> getFavVideosByUser(
    int userId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    _ensureInitialized();
    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/space/fav/arc/list',
        queryParameters: {
          'vmid': userId,
          'pn': page,
          'ps': pageSize,
        },
        options: _buildOptions(),
      );
      final data = response.data;
      final code = data['code'] as int? ?? -1;

      if (code == -101) {
        throw BilibiliApiException(-101, '登录已过期，请重新登录Bilibili');
      }

      if (code == 0 && data['data'] != null) {
        final result = data['data'];
        final list = result['list'] as List? ?? [];
        final pageInfo = result['page'] as Map<String, dynamic>? ?? {};

        final videos = <BilibiliVideo>[];
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          // Response format for space/fav/arc is different from fav/res
          final bvid = map['bvid'] as String? ?? '';
          final avid = map['id'] as int? ?? 0;
          final durationSeconds = map['duration'] as int? ?? 0;
          final title = map['title'] as String? ?? '未知标题';
          final coverUrl = map['pic'] as String? ?? '';
          final ownerName = (map['owner'] is Map)
              ? (map['owner']['name'] as String? ?? '未知UP主')
              : '未知UP主';

          // cid may not be in the response — need a separate API call
          // Set to 0 here; it will be fetched later when downloading
          videos.add(BilibiliVideo(
            bvid: bvid,
            avid: avid,
            cid: 0, // Will be resolved when fetching audio URL
            title: title,
            coverUrl: coverUrl,
            ownerName: ownerName,
            durationSeconds: durationSeconds,
          ));
        }

        return {
          'videos': videos,
          'has_more': page - 1 <
              ((pageInfo['count'] as int? ?? 0) / pageSize).ceil() - 1,
          'total': pageInfo['count'] as int? ?? videos.length,
        };
      }

      if (code != 0) {
        throw BilibiliApiException(
            code, data['message'] as String? ?? '未知错误($code)');
      }

      return null;
    } on BilibiliApiException {
      rethrow;
    } on DioException catch (e) {
      throw BilibiliApiException(-2, '网络错误: ${e.message}');
    }
  }

  /// Get video's cid (needed for audio URL).
  /// This is a lightweight API call that returns the video's page info.
  Future<int?> getVideoCid(String bvid) async {
    _ensureInitialized();
    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/web-interface/view',
        queryParameters: {'bvid': bvid},
        options: _buildOptions(),
      );
      final data = response.data;
      if (data['code'] == 0 && data['data'] != null) {
        final pages = data['data']['pages'] as List?;
        if (pages != null && pages.isNotEmpty) {
          return pages[0]['cid'] as int?;
        }
        return data['data']['cid'] as int?;
      }
      return null;
    } on DioException {
      return null;
    }
  }

  /// Get audio stream URL for a video (DASH format, audio-only stream).
  /// If cid is 0, will try to look it up from the video info API.
  Future<String?> getAudioUrl(String bvid, int cid) async {
    _ensureInitialized();

    // If cid is unknown, try to resolve it
    int resolvedCid = cid;
    if (resolvedCid == 0) {
      final found = await getVideoCid(bvid);
      if (found == null) return null;
      resolvedCid = found;
    }

    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/player/playurl',
        queryParameters: {
          'bvid': bvid,
          'cid': resolvedCid,
          'fnval': 16, // Request DASH format
          'qn': 0,
          'fnver': 0,
          'fourk': 1,
          'platform': 'web',
        },
        options: _buildOptions(),
      );
      final data = response.data;
      if (data['code'] == 0 && data['data'] != null) {
        // Try DASH audio first
        final dash = data['data']['dash'];
        if (dash != null) {
          final audioStreams = dash['audio'] as List?;
          if (audioStreams != null && audioStreams.isNotEmpty) {
            // Pick highest quality audio
            final audio = audioStreams.last as Map<String, dynamic>;
            return audio['baseUrl'] as String? ?? audio['base_url'] as String?;
          }
        }

        // Fallback: try the regular durl (non-DASH)
        final durl = data['data']['durl'] as List?;
        if (durl != null && durl.isNotEmpty) {
          return durl[0]['url'] as String?;
        }
      }
      return null;
    } on DioException {
      return null;
    }
  }

  /// Get a Dio instance configured for downloading
  Dio getDownloadDio() {
    return Dio(BaseOptions(
      headers: {
        'User-Agent': _userAgent,
        'Referer': 'https://www.bilibili.com',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 30),
    ));
  }
}
