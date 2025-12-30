enum AttachmentType { image, video, voice, document }

class ChatAttachment {
  final int? id;
  final AttachmentType type;
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final bool isViewOnce;
  final String? localPath; // For downloaded files

  ChatAttachment({
    this.id,
    required this.type,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    this.isViewOnce = false,
    this.localPath,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['attachment_id'],
      type: _parseType(json['file_type']),
      fileUrl: json['file_url'] ?? '', // Should be constructed from baseUrl + endpoint
      fileName: json['file_name'] ?? 'File',
      fileSize: json['size'] ?? 0,
      isViewOnce: json['is_view_once'] ?? false,
    );
  }

  static AttachmentType _parseType(String type) {
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
