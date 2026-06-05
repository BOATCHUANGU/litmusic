import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bilibili_video.dart';
import '../providers/bilibili_provider.dart';

class BilibiliVideoTile extends StatelessWidget {
  final BilibiliVideo video;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BilibiliVideoTile({
    super.key,
    required this.video,
    this.isSelected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bili = context.watch<BilibiliProvider>();
    final downloading = bili.isDownloading(video.bvid);
    final downloaded = bili.isDownloaded(video.bvid);
    final progress = bili.getDownloadProgress(video.bvid);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.withAlpha(40) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: Colors.deepPurple, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 80,
                height: 50,
                child: video.coverUrl.isNotEmpty
                    ? Image.network(
                        video.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 13, color: Colors.white38),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          video.ownerName,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 13, color: Colors.white38),
                      const SizedBox(width: 3),
                      Text(
                        video.durationFormatted,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action
            if (selectionMode)
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.deepPurple : Colors.white38,
                size: 24,
              )
            else if (downloaded)
              const Icon(Icons.check_circle, color: Colors.green, size: 24)
            else if (downloading)
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Colors.white10,
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.download_rounded,
                    color: Colors.white54, size: 22),
                tooltip: '下载音频',
                onPressed: () {
                  final biliProvider = context.read<BilibiliProvider>();
                  biliProvider.downloadAudio(video);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.white10,
      child: const Icon(Icons.play_circle_outline, color: Colors.white24, size: 30),
    );
  }
}
