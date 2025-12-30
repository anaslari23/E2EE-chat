import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../domain/attachment.dart';

class MediaBubble extends StatefulWidget {
  final ChatAttachment attachment;
  final bool isMe;

  const MediaBubble({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  @override
  State<MediaBubble> createState() => _MediaBubbleState();
}

class _MediaBubbleState extends State<MediaBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      // In a real app, widget.attachment.fileUrl would point to our download API
      // For now, we simulate with the URL
      await _audioPlayer.play(UrlSource(widget.attachment.fileUrl));
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        widget.attachment.fileUrl,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 200,
          height: 200,
          color: Colors.grey.withAlpha(50),
          child: const Icon(Icons.image_not_supported),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white24 : Colors.grey.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _playerState == PlayerState.playing ? Icons.pause : Icons.play_arrow,
              color: widget.isMe ? Colors.white : const Color(0xFF2166EE),
            ),
            onPressed: _toggleAudio,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0 
                      ? _position.inMilliseconds / _duration.inMilliseconds 
                      : 0,
                  backgroundColor: Colors.grey.withAlpha(50),
                  color: widget.isMe ? Colors.white : const Color(0xFF2166EE),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const Icon(Icons.mic, size: 12, color: Colors.grey),
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
