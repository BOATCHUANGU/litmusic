import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import '../models/song.dart';
import '../services/database_helper.dart';

class MusicProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<Song> _songs = [];
  Set<String> _favoriteSongIds = {};
  String? _currentUserId;

  List<Song> get songs => _songs;
  Set<String> get favoriteSongIds => _favoriteSongIds;

  Future<void> loadSongs() async {
    _songs = await _db.getAllSongs();
    notifyListeners();
  }

  Future<void> loadFavorites(String userId) async {
    _currentUserId = userId;
    final ids = await _db.getFavoriteSongIds(userId);
    _favoriteSongIds = Set.from(ids);
    notifyListeners();
  }

  bool isFavorite(String songId) => _favoriteSongIds.contains(songId);

  void updateSongDuration(String songId, int seconds) {
    final idx = _songs.indexWhere((s) => s.id == songId);
    if (idx != -1 && _songs[idx].durationSeconds == 0 && seconds > 0) {
      _songs[idx] = Song(
        id: _songs[idx].id,
        title: _songs[idx].title,
        artist: _songs[idx].artist,
        filePath: _songs[idx].filePath,
        durationSeconds: seconds,
      );
      _db.updateSongDuration(songId, seconds);
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String songId) async {
    if (_currentUserId == null) return;
    if (_favoriteSongIds.contains(songId)) {
      await _db.removeFavorite(_currentUserId!, songId);
      _favoriteSongIds.remove(songId);
    } else {
      await _db.addFavorite(_currentUserId!, songId);
      _favoriteSongIds.add(songId);
    }
    notifyListeners();
  }

  List<Song> get favoriteSongs =>
      _songs.where((s) => _favoriteSongIds.contains(s.id)).toList();

  Future<String?> importMusicFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final musicDir = Directory(p.join(appDir.path, 'music'));
    if (!await musicDir.exists()) {
      await musicDir.create(recursive: true);
    }

    int imported = 0;
    final existingPaths = _songs.map((s) => s.filePath).toSet();

    for (final file in result.files) {
      if (file.path == null) continue;

      final srcFile = File(file.path!);
      final ext = p.extension(file.path!);
      final newName = '${const Uuid().v4()}$ext';
      final destPath = p.join(musicDir.path, newName);

      if (existingPaths.contains(destPath)) continue;

      try {
        await srcFile.copy(destPath);

        final title = p.basenameWithoutExtension(file.name);

        await _db.insertSong(Song(
          id: const Uuid().v4(),
          title: title,
          artist: '未知歌手',
          filePath: destPath,
          durationSeconds: 0,
        ));
        imported++;
      } catch (_) {
        // Skip files that fail to copy
      }
    }

    if (imported > 0) {
      await loadSongs();
    }
    return imported > 0 ? '成功导入 $imported 首歌曲' : '未发现新的音乐文件';
  }

  Future<void> deleteSong(String songId) async {
    final song = _songs.firstWhere((s) => s.id == songId);
    try {
      await File(song.filePath).delete();
    } catch (_) {}
    await _db.deleteSong(songId);
    _favoriteSongIds.remove(songId);
    await loadSongs();
  }

  Song? getSongById(String id) {
    try {
      return _songs.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
