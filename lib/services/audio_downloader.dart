import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'bilibili_api.dart';

class AudioDownloader {
  /// Download audio from a URL and save to local music directory.
  ///
  /// [url] — the audio stream URL from Bilibili
  /// [fileName] — the display title (used for Song metadata, not filename)
  /// [ownerName] — UP主 name (used as artist)
  /// [durationSeconds] — duration in seconds
  /// [onProgress] — called with (receivedBytes, totalBytes) during download
  ///
  /// Returns the local file path on success, throws on failure.
  static Future<String> downloadAudio({
    required String url,
    required String fileName,
    required String ownerName,
    required int durationSeconds,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final musicDir = Directory(p.join(appDir.path, 'music'));
    if (!await musicDir.exists()) {
      await musicDir.create(recursive: true);
    }

    // Generate unique filename with .m4a extension (Bilibili DASH audio is AAC)
    final newName = '${const Uuid().v4()}.m4a';
    final destPath = p.join(musicDir.path, newName);

    final downloadDio = BilibiliApi().getDownloadDio();

    await downloadDio.download(
      url,
      destPath,
      onReceiveProgress: (received, total) {
        onProgress?.call(received, total);
      },
      cancelToken: cancelToken,
      options: Options(
        headers: {
          'Referer': 'https://www.bilibili.com',
        },
      ),
    );

    // Verify the file exists and has content
    final file = File(destPath);
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('下载失败：文件为空或不存在');
    }

    return destPath;
  }
}
