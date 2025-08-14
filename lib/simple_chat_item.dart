import 'package:flutter/material.dart';

// Re-defining enums and classes for simplicity in this standalone file.
enum ChatType { text, image }

class ChatUser {
  final int id;
  final String fullName;
  final String avatar;

  ChatUser({required this.id, required this.fullName, required this.avatar});
}

class ChatDetail {
  final int id;
  final String content;
  final String? href;
  final ChatUser user;
  final ChatType type;
  final DateTime createdAt;

  ChatDetail({
    required this.id,
    this.content = '',
    this.href,
    required this.user,
    required this.type,
    required this.createdAt,
  });
}

class SimpleChatItem extends StatelessWidget {
  final ChatDetail message;
  final bool isMine;

  const SimpleChatItem({
    super.key,
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMine ? Colors.blue[100] : Colors.grey[200];
    final textColor = isMine ? Colors.black : Colors.black;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(message.user.avatar),
              ),
            if (!isMine) const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _buildMessageContent(textColor),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 40, right: 40),
          child: Text(
            '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMessageContent(Color textColor) {
    if (message.type == ChatType.image && message.href != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 250,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            message.href!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error, color: Colors.red);
            },
          ),
        ),
      );
    }
    return Text(
      message.content,
      style: TextStyle(color: textColor, fontSize: 16),
    );
  }
}
