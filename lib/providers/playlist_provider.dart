import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist.dart';
import '../services/database_helper.dart';

class PlaylistProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<Playlist> _playlists = [];
  String? _currentUserId;

  List<Playlist> get playlists => _playlists;

  Future<void> loadPlaylists(String userId) async {
    _currentUserId = userId;
    _playlists = await _db.getPlaylistsByUser(userId);
    notifyListeners();
  }

  Future<String?> createPlaylist(String name) async {
    if (_currentUserId == null) return '未登录';
    if (name.trim().isEmpty) return '歌单名称不能为空';

    final playlist = Playlist(
      id: const Uuid().v4(),
      userId: _currentUserId!,
      name: name.trim(),
    );
    await _db.createPlaylist(playlist);
    await loadPlaylists(_currentUserId!);
    return null;
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _db.deletePlaylist(playlistId);
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
  }

  Future<bool> addSongToPlaylist(String playlistId, String songId) async {
    await _db.addSongToPlaylist(playlistId, songId);
    await loadPlaylists(_currentUserId!);
    return true;
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await _db.removeSongFromPlaylist(playlistId, songId);
    await loadPlaylists(_currentUserId!);
  }

  Playlist? getPlaylistById(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  bool isSongInPlaylist(String playlistId, String songId) {
    final playlist = getPlaylistById(playlistId);
    if (playlist == null) return false;
    return playlist.songIds.contains(songId);
  }

  void clearAndNotify() {
    _playlists = [];
    _currentUserId = null;
    notifyListeners();
  }
}
