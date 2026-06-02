import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/user.dart';
import '../models/song.dart';
import '../models/playlist.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static bool _ffiInitialized = false;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!_ffiInitialized &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'litmusic.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE songs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL DEFAULT '未知歌手',
        file_path TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE favorites (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        song_id TEXT NOT NULL,
        UNIQUE(user_id, song_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_songs (
        id TEXT PRIMARY KEY,
        playlist_id TEXT NOT NULL,
        song_id TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ===================== User =====================

  Future<bool> registerUser(String username, String password) async {
    final db = await database;
    try {
      await db.insert('users', {
        'id': username,
        'username': username,
        'password': password,
      });
      return true;
    } catch (_) {
      return false; // username already exists
    }
  }

  Future<User?> loginUser(String username, String password) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    if (results.isEmpty) return null;
    return User.fromMap(results.first);
  }

  // ===================== Song =====================

  Future<void> insertSong(Song song) async {
    final db = await database;
    await db.insert('songs', song.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Song>> getAllSongs() async {
    final db = await database;
    final results = await db.query('songs', orderBy: 'title');
    return results.map((e) => Song.fromMap(e)).toList();
  }

  Future<void> deleteSong(String songId) async {
    final db = await database;
    await db.delete('songs', where: 'id = ?', whereArgs: [songId]);
    await db.delete('favorites', where: 'song_id = ?', whereArgs: [songId]);
    await db.delete('playlist_songs', where: 'song_id = ?', whereArgs: [songId]);
  }

  Future<void> updateSongDuration(String songId, int durationSeconds) async {
    final db = await database;
    await db.update(
      'songs',
      {'duration_seconds': durationSeconds},
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  // ===================== Favorites =====================

  Future<void> addFavorite(String userId, String songId) async {
    final db = await database;
    await db.insert('favorites', {
      'id': '${userId}_$songId',
      'user_id': userId,
      'song_id': songId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeFavorite(String userId, String songId) async {
    final db = await database;
    await db.delete('favorites',
        where: 'user_id = ? AND song_id = ?', whereArgs: [userId, songId]);
  }

  Future<List<String>> getFavoriteSongIds(String userId) async {
    final db = await database;
    final results = await db.query('favorites',
        where: 'user_id = ?', whereArgs: [userId]);
    return results.map((e) => e['song_id'] as String).toList();
  }

  Future<bool> isFavorite(String userId, String songId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM favorites WHERE user_id = ? AND song_id = ?',
      [userId, songId],
    ));
    return (count ?? 0) > 0;
  }

  // ===================== Playlist =====================

  Future<void> createPlaylist(Playlist playlist) async {
    final db = await database;
    await db.insert('playlists', playlist.toMap());
  }

  Future<List<Playlist>> getPlaylistsByUser(String userId) async {
    final db = await database;
    final results = await db.query('playlists',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'name');
    final playlists = <Playlist>[];
    for (final row in results) {
      final songRows = await db.query('playlist_songs',
          where: 'playlist_id = ?',
          whereArgs: [row['id']],
          orderBy: 'position');
      final songIds = songRows.map((s) => s['song_id'] as String).toList();
      playlists.add(Playlist(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        name: row['name'] as String,
        songIds: songIds,
      ));
    }
    return playlists;
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final db = await database;
    final maxPos = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT MAX(position) FROM playlist_songs WHERE playlist_id = ?',
      [playlistId],
    ));
    await db.insert('playlist_songs', {
      'id': '${playlistId}_$songId',
      'playlist_id': playlistId,
      'song_id': songId,
      'position': (maxPos ?? -1) + 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final db = await database;
    await db.delete('playlist_songs',
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songId]);
  }

  Future<void> deletePlaylist(String playlistId) async {
    final db = await database;
    await db.delete('playlist_songs',
        where: 'playlist_id = ?', whereArgs: [playlistId]);
    await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
  }
}
