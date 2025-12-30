import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/attachment.dart';
import '../../../../core/providers.dart';
import 'full_screen_viewer.dart';
import 'package:video_player/video_player.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class MediaBubble extends ConsumerStatefulWidget {
  final ChatAttachment attachment;
  final bool isMe;

  const MediaBubble({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  @override
  ConsumerState<MediaBubble> createState() => _MediaBubbleState();
}

class _MediaBubbleState extends ConsumerState<MediaBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _decryptedPath;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _checkLocalFile();
    if (widget.attachment.type == AttachmentType.voice) {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _playerState = state);
      });
      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
    }
  }

  Future<void> _checkLocalFile() async {
    if (widget.attachment.localPath != null) {
      if (await File(widget.attachment.localPath!).exists()) {
        if (mounted) setState(() => _decryptedPath = widget.attachment.localPath);
        return;
      }
    }
  }

  Future<void> _downloadAndDecrypt() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.1;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final encryption = ref.read(encryptionServiceProvider);
      
      final encryptedBytes = await api.downloadMedia(widget.attachment.id!);
      setState(() => _downloadProgress = 0.5);

      if (widget.attachment.mediaKey == null || widget.attachment.mediaNonce == null) {
        throw Exception('Media key missing');
      }

      final decryptedBytes = await encryption.decryptMedia(
        Uint8List.fromList(encryptedBytes),
        widget.attachment.mediaKey!,
        widget.attachment.mediaNonce!,
      );
      setState(() => _downloadProgress = 0.8);

      final dir = await getTemporaryDirectory();
      final extension = widget.attachment.fileName.split('.').last;
      final file = File('${dir.path}/decrypted_${widget.attachment.id}.$extension');
      await file.writeAsBytes(decryptedBytes);

      if (mounted) {
        setState(() {
          _decryptedPath = file.path;
          _isDownloading = false;
        });
      }

      if (widget.attachment.type == AttachmentType.video) {
        _videoController = VideoPlayerController.file(file)
          ..initialize().then((_) => setState(() {}));
      }
    } catch (e) {
      print('Download/Decrypt error: $e');
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_decryptedPath == null) {
      await _downloadAndDecrypt();
    }
    
    if (_decryptedPath == null) return;

    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(_decryptedPath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.attachment.type) {
      case AttachmentType.image:
        return _buildImage();
      case AttachmentType.video:
        return _buildVideo();
      case AttachmentType.voice:
        return _buildVoice();
      case AttachmentType.document:
        return _buildDocument();
    }
  }

  Widget _buildImage() {
    return GestureDetector(
      onTap: () {
        if (_decryptedPath != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenMediaViewer(
                file: File(_decryptedPath!),
                fileName: widget.attachment.fileName,
              ),
            ),
          );
        } else {
          _downloadAndDecrypt();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _decryptedPath != null
                ? Image.file(
                    File(_decryptedPath!),
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey.withAlpha(50),
                    child: _isDownloading
                        ? Center(
                            child: CircularProgressIndicator(
                              value: _downloadProgress,
                              color: const Color(0xFF2166EE),
                            ),
                          )
                        : const Icon(Icons.download, color: Colors.grey),
                  ),
            if (_decryptedPath == null && !_isDownloading)
              const Positioned(
                bottom: 8,
                right: 8,
                child: Icon(Icons.lock_outline, size: 14, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildImage(), // Video thumbnail
        Container(
          decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
        ),
      ],
    );
  }

  Widget _buildVoice() {
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white24 : Colors.grey.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _isDownloading 
            ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
            : IconButton(
                icon: Icon(
                  _playerState == PlayerState.playing ? Icons.pause : Icons.play_arrow,
                  color: widget.isMe ? Colors.white : const Color(0xFF2166EE),
                ),
                onPressed: _toggleAudio,
              ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 30,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: WaveformPainter(
                      progress: _duration.inMilliseconds > 0 
                          ? _position.inMilliseconds / _duration.inMilliseconds 
                          : 0,
                      color: widget.isMe ? Colors.white70 : const Color(0xFF2166EE).withOpacity(0.5),
                      activeColor: widget.isMe ? Colors.white : const Color(0xFF2166EE),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocument() {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white10 : Colors.grey.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, color: Color(0xFF2166EE)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  _formatFileSize(widget.attachment.fileSize),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  String _formatFileSize(int size) {
    if (size < 1024) return "$size B";
    if (size < 1024 * 1024) return "${(size / 1024).toStringAsFixed(1)} KB";
    return "${(size / (1024 * 1024)).toStringAsFixed(1)} MB";
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color activeColor;

  WaveformPainter({
    required this.progress,
    required this.color,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    const int barCount = 30;
    final double barWidth = size.width / (barCount * 1.5);
    final double gap = barWidth * 0.5;

    // Fixed random-ish heights for visualization
    final List<double> heights = [
      0.4, 0.7, 0.5, 0.8, 0.6, 0.9, 0.4, 0.5, 0.7, 0.3,
      0.6, 0.8, 0.5, 0.7, 0.4, 0.9, 0.6, 0.8, 0.5, 0.4,
      0.7, 0.3, 0.6, 0.8, 0.5, 0.9, 0.4, 0.7, 0.5, 0.6
    ];

    for (int i = 0; i < barCount; i++) {
      final double x = i * (barWidth + gap);
      final double h = heights[i % heights.length] * size.height;
      final double y = (size.height - h) / 2;

      paint.color = (i / barCount) < progress ? activeColor : color;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
