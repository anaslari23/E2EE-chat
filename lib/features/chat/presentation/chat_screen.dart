import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/message.dart';
import 'providers/message_provider.dart';
import 'providers/media_notifier.dart';
import 'widgets/media_bubble.dart';
import '../../../core/providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String id;
  const ChatScreen({super.key, required this.id});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;
  bool _isTextEmpty = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _isTextEmpty = _controller.text.trim().isEmpty);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contactId = int.tryParse(widget.id);
      if (contactId != null) {
        ref.read(messagesProvider.notifier).fetchHistory(contactId);
      }
    });
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final content = _controller.text.trim();
    
    if (_editingMessage != null) {
      ref.read(messagesProvider.notifier).editMessage(_editingMessage!.id!, content);
      _cancelAction();
      return;
    }

    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      content: content,
      isMe: true,
      timestamp: DateTime.now(),
      parentId: _replyingTo?.id,
    );

    ref.read(messagesProvider.notifier).addMessage(newMessage);
    _cancelAction();
  }

  void _cancelAction() {
    setState(() {
      _replyingTo = null;
      _editingMessage = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final isRecording = ref.watch(mediaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(30),
              child: Text(
                widget.id[0].toUpperCase(), 
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Chat ${widget.id}"),
                Text(
                  "Encrypted", 
                  style: TextStyle(
                    fontSize: 11, 
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final parentMessage = message.parentId != null 
                    ? messages.firstWhere((m) => m.id == message.parentId, orElse: () => message) 
                    : null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _Bubble(
                    message: message,
                    parentMessage: parentMessage,
                    onReply: () => setState(() => _replyingTo = message),
                    onAction: (action) {
                      if (action == 'edit') {
                        setState(() {
                          _editingMessage = message;
                          _controller.text = message.content;
                        });
                      } else if (action == 'delete') {
                        _showDeleteDialog(message);
                      } else if (action == 'star') {
                        ref.read(messagesProvider.notifier).toggleStar(message.id!);
                      }
                    },
                    onReact: (emoji) {
                      ref.read(messagesProvider.notifier).addReaction(message.id!, emoji);
                    },
                  ),
                );
              },
            ),
          ),
          if (_replyingTo != null || _editingMessage != null) _buildActionPreview(),
          _buildMessageInput(isRecording),
        ],
      ),
    );
  }

  void _showDeleteDialog(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('Select deletion mode.'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(messagesProvider.notifier).deleteMessage(message.id!);
              Navigator.pop(context);
            },
            child: const Text('DELETE FOR ME'),
          ),
          if (message.isMe)
            TextButton(
              onPressed: () {
                ref.read(messagesProvider.notifier).deleteMessage(message.id!, forEveryone: true);
                Navigator.pop(context);
              },
              child: const Text('DELETE FOR EVERYONE', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildActionPreview() {
    final title = _editingMessage != null ? 'Editing message' : 'Replying to';
    final content = _editingMessage?.content ?? _replyingTo?.content ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.withAlpha(20),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: Color(0xFF2166EE)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2166EE))),
                Text(content, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() {
              _replyingTo = null;
              _editingMessage = null;
              if (_editingMessage != null) _controller.clear();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isRecording) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF2166EE)), 
                onPressed: () => ref.read(mediaProvider.notifier).pickAndSendMedia(widget.id),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: isRecording
                  ? _buildRecordingStatus()
                  : TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a secure message...',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            _buildActionIcon(isRecording),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          const Text("Recording...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Text("Release to send", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionIcon(bool isRecording) {
    if (!_isTextEmpty) {
      return Container(
        decoration: const BoxDecoration(color: Color(0xFF2166EE), shape: BoxShape.circle),
        child: IconButton(
          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          onPressed: _sendMessage,
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => ref.read(mediaProvider.notifier).startRecording(),
      onLongPressEnd: (_) => ref.read(mediaProvider.notifier).stopAndSendRecording(widget.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRecording ? Colors.red : const Color(0xFF2166EE),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isRecording ? Icons.mic : Icons.mic_none,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onReply;
  final Function(String)? onAction;
  final Function(String)? onReact;
  final ChatMessage? parentMessage;

  const _Bubble({
    required this.message, 
    this.onReply, 
    this.onAction,
    this.onReact,
    this.parentMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMedia = message.messageType != 'text';
    
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        child: Column(
          crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (parentMessage != null) _buildReplyContext(context),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding: isMedia ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMedia 
                      ? Colors.transparent 
                      : (message.isDeleted
                        ? Colors.grey.withAlpha(20)
                        : (message.isMe
                          ? const Color(0xFF2166EE)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white))),
                    borderRadius: BorderRadius.circular(20),
                    border: message.isDeleted ? Border.all(color: Colors.grey.withAlpha(50)) : null,
                  ),
                  child: isMedia && !message.messageType.contains('text') && message.attachments.isNotEmpty
                    ? MediaBubble(attachment: message.attachments.first, isMe: message.isMe)
                    : _buildTextContent(isDark),
                ),
                if (message.reactions.isNotEmpty && !message.isDeleted)
                  Positioned(
                    bottom: -15,
                    right: message.isMe ? 0 : null,
                    left: message.isMe ? null : 0,
                    child: _buildReactions(),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                if (message.isMe && !message.isDeleted) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == 'delivered' ? Icons.done_all : Icons.done,
                    size: 12,
                    color: message.status == 'delivered' ? const Color(0xFF2166EE) : Colors.grey,
                  ),
                ],
                if (message.isStarred) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.star, size: 12, color: Colors.amber),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.isDeleted ? 'Message was deleted' : message.content,
          style: TextStyle(
            color: message.isDeleted 
              ? Colors.grey 
              : (message.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87)),
            fontSize: 15,
            fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        if (message.isEdited && !message.isDeleted)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Edited',
              style: TextStyle(
                fontSize: 10,
                color: message.isMe ? Colors.white70 : Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReactions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: message.reactions.take(3).map((r) => Text(r.emoji, style: const TextStyle(fontSize: 12))).toList(),
      ),
    );
  }

  Widget _buildReplyContext(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: Color(0xFF2166EE), width: 4)),
      ),
      child: Text(
        parentMessage!.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.isDeleted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        onReact?.call(emoji);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    );
                  }).toList(),
                ),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply?.call();
              },
            ),
            if (message.isMe && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  onAction?.call('edit');
                },
              ),
            ListTile(
              leading: Icon(message.isStarred ? Icons.star : Icons.star_border),
              title: Text(message.isStarred ? 'Unstar' : 'Star'),
              onTap: () {
                Navigator.pop(context);
                onAction?.call('star');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onAction?.call('delete');
              },
            ),
          ],
        ),
      ),
    );
  }
}
