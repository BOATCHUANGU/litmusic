import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

enum PlayMode { sequential, shuffle, singleRepeat }

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  List<Song> _queue = [];
  int _currentIndex = -1;
  PlayMode _playMode = PlayMode.sequential;
  void Function(String songId, int seconds)? onDurationKnown;

  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  PlayMode get playMode => _playMode;
  bool get hasSong => _currentIndex >= 0 && _currentIndex < _queue.length;

  Song? get currentSong {
    if (!hasSong) return null;
    return _queue[_currentIndex];
  }

  PlayerProvider() {
    // Track completion — audioplayers fires this as a Stream<void>.
    _player.onPlayerComplete.listen((_) {
      _onSongCompleted();
    });

    // Position updates with throttle.
    _player.onPositionChanged.listen((pos) {
      _throttledPosition = pos;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastPositionEmit > 500) {
        _lastPositionEmit = now;
        notifyListeners();
      }
    });

    // Capture real duration and surface it to the song provider.
    _player.onDurationChanged.listen((d) {
      _duration = d;
      if (onDurationKnown != null && hasSong && d.inSeconds > 0) {
        onDurationKnown!(currentSong!.id, d.inSeconds);
      }
    });

    // Sync isPlaying with native state changes (play / pause / stop).
    _player.onPlayerStateChanged.listen((_) => notifyListeners());
  }

  int _lastPositionEmit = 0;
  Duration _throttledPosition = Duration.zero;
  Duration? _duration;

  Duration get position => _throttledPosition;
  Duration? get duration => _duration;

  // We expose these for the seek bar — they're set once and then they're
  // stable, so they won't cause rebuild storms.
  void _onSongCompleted() {
    switch (_playMode) {
      case PlayMode.sequential:
        _playNext();
        break;
      case PlayMode.shuffle:
        _playNext();
        break;
      case PlayMode.singleRepeat:
        _player.seek(Duration.zero);
        _player.resume();
        break;
    }
  }

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  PlayMode get nextPlayMode {
    switch (_playMode) {
      case PlayMode.sequential:
        return PlayMode.shuffle;
      case PlayMode.shuffle:
        return PlayMode.singleRepeat;
      case PlayMode.singleRepeat:
        return PlayMode.sequential;
    }
  }

  String get playModeLabel {
    switch (_playMode) {
      case PlayMode.sequential:
        return '顺序播放';
      case PlayMode.shuffle:
        return '随机播放';
      case PlayMode.singleRepeat:
        return '单曲循环';
    }
  }

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Stage 1 (sync): set up the queue so the player page knows what to show.
  void prepareSong(Song song, {List<Song>? queue}) {
    _error = null;
    if (queue != null) {
      _queue = queue;
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) _currentIndex = 0;
    } else {
      if (!_queue.any((s) => s.id == song.id)) {
        _queue = [song];
      }
      _currentIndex = 0;
    }
    notifyListeners();
  }

  /// Stage 2 (async): open the file and start playback.
  /// audioplayers' `play()` returns immediately — the native side
  /// loads the file asynchronously, so the Dart event loop stays free.
  Future<void> loadCurrentSong() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final song = _queue[_currentIndex];
    try {
      await _player.play(DeviceFileSource(song.filePath));
      _isLoading = false;
      _throttledPosition = Duration.zero;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      _error = '无法播放: ${song.title}';
      notifyListeners();
    }
  }

  /// Convenience: prepare + load in one call (used by play-next / skip).
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    prepareSong(song, queue: queue);
    await loadCurrentSong();
  }

  Future<void> playOrPause() async {
    switch (_player.state) {
      case PlayerState.playing:
        await _player.pause();
        break;
      case PlayerState.paused:
        await _player.resume();
        break;
      default:
        if (hasSong) await loadCurrentSong();
        break;
    }
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> _playNext() async {
    if (_queue.isEmpty) return;

    switch (_playMode) {
      case PlayMode.sequential:
      case PlayMode.singleRepeat:
        if (_currentIndex < _queue.length - 1) {
          _currentIndex++;
        } else {
          await _player.pause();
          notifyListeners();
          return;
        }
        break;
      case PlayMode.shuffle:
        if (_queue.length == 1) {
          await _player.seek(Duration.zero);
          await _player.resume();
          return;
        }
        int nextIndex;
        do {
          nextIndex = DateTime.now().millisecondsSinceEpoch % _queue.length;
        } while (nextIndex == _currentIndex);
        _currentIndex = nextIndex;
        break;
    }

    final song = _queue[_currentIndex];
    try {
      await _player.play(DeviceFileSource(song.filePath));
    } catch (_) {
      _handleBrokenTrack(_currentIndex);
      return;
    }
    notifyListeners();
  }

  Future<void> playNext() async {
    if (_queue.isEmpty) return;

    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }

    final song = _queue[_currentIndex];
    try {
      await _player.play(DeviceFileSource(song.filePath));
    } catch (_) {
      _handleBrokenTrack(_currentIndex);
      return;
    }
    notifyListeners();
  }

  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;

    final position = _throttledPosition;
    if (position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      notifyListeners();
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = _queue.length - 1;
    }
    final song = _queue[_currentIndex];
    try {
      await _player.play(DeviceFileSource(song.filePath));
    } catch (_) {
      _handleBrokenTrack(_currentIndex);
      return;
    }
    notifyListeners();
  }

  /// Remove a broken / unplayable track from the queue and try the next one.
  void _handleBrokenTrack(int index) {
    if (_queue.isEmpty) return;
    _queue.removeAt(index.clamp(0, _queue.length - 1));
    if (_queue.isEmpty) {
      _currentIndex = -1;
      notifyListeners();
      return;
    }
    if (index >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    final next = _queue[_currentIndex];
    playSong(next, queue: _queue);
  }

  bool get isPlaying => _player.state == PlayerState.playing;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
