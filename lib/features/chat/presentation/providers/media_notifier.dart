import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'message_provider.dart';
import '../../domain/message.dart';
import '../../domain/attachment.dart';
import '../../../../services/api_service.dart';
import '../../../../core/providers.dart';

class MediaNotifier extends StateNotifier<bool> {
  final Ref ref;
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;

  MediaNotifier(this.ref) : super(false);

  Future<void> pickAndSendMedia(String chatId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final bytes = await file.readAsBytes();
      
      await _sendMediaMessage(chatId, fileName, bytes, _determineType(fileName));
    }
  }

  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _recorder.start(const RecordConfig(), path: _recordingPath!);
      state = true;
    }
  }

  Future<void> stopAndSendRecording(String chatId) async {
    final path = await _recorder.stop();
    state = false;
    
    if (path != null) {
      final file = File(path);
      final bytes = await file.readAsBytes();
      await _sendMediaMessage(chatId, 'Voice Note.m4a', bytes, AttachmentType.voice);
    }
  }

  Future<void> _sendMediaMessage(
    String chatId, 
    String fileName, 
    List<int> bytes, 
    AttachmentType type
  ) async {
    final messageNotifier = ref.read(messagesProvider.notifier);
    final api = ref.read(apiServiceProvider);

    // 1. Create temporary message
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = ChatMessage(
      id: tempId,
      content: type == AttachmentType.voice ? 'Voice Note' : fileName,
      isMe: true,
      timestamp: DateTime.now(),
      messageType: type.name,
      status: 'pending',
    );
    messageNotifier.addMessage(tempMessage);

    try {
      // 2. Upload media (In real app, encrypt bytes first)
      final uploadResult = await api.uploadMedia(
        tempId, 
        type.name, 
        bytes, 
        fileName
      );

      // 3. Update message status
      // In a real app, we'd send the message via WebSocket with attachment IDs
      print('Media uploaded: ${uploadResult['attachment_id']}');
    } catch (e) {
      print('Failed to send media: $e');
    }
  }

  AttachmentType _determineType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) return AttachmentType.image;
    if (['mp4', 'mov', 'avi'].contains(ext)) return AttachmentType.video;
    if (['mp3', 'm4a', 'wav'].contains(ext)) return AttachmentType.voice;
    return AttachmentType.document;
  }
}

final mediaProvider = StateNotifierProvider<MediaNotifier, bool>((ref) {
  return MediaNotifier(ref);
});
