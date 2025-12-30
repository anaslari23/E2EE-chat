import 'dart:typed_data';

enum AttachmentType { image, video, voice, document }

class ChatAttachment {
  final int? id;
  final AttachmentType type;
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final bool isViewOnce;
  final String? localPath; // For downloaded files
  final Uint8List? mediaKey;
  final Uint8List? mediaNonce;

  ChatAttachment({
    this.id,
    required this.type,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    this.isViewOnce = false,
    this.localPath,
    this.mediaKey,
    this.mediaNonce,
  });

  ChatAttachment copyWith({
    String? localPath,
    Uint8List? mediaKey,
    Uint8List? mediaNonce,
  }) {
    return ChatAttachment(
      id: id,
      type: type,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      isViewOnce: isViewOnce,
      localPath: localPath ?? this.localPath,
      mediaKey: mediaKey ?? this.mediaKey,
      mediaNonce: mediaNonce ?? this.mediaNonce,
    );
  }

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['attachment_id'],
      type: parseType(json['file_type']),
      fileUrl: json['file_url'] ?? '',
      fileName: json['file_name'] ?? 'File',
      fileSize: json['size'] ?? 0,
      isViewOnce: json['is_view_once'] ?? false,
    );
  }

  static AttachmentType parseType(String type) {
    switch (type) {
      case 'video':
        return AttachmentType.video;
      case 'voice':
        return AttachmentType.voice;
      case 'document':
        return AttachmentType.document;
      case 'image':
      default:
        return AttachmentType.image;
    }
  }
}
