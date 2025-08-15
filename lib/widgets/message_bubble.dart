import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/widgets/chat_image_grid.dart';
import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:image_picker_with_draggable/models/message.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.onRetry});

  final Message message;
  final void Function(Attachment attachment)? onRetry;

  @override
  Widget build(BuildContext context) {
    final hasAttachments = message.attachments.isNotEmpty;
    return Align(
      alignment:
          message.isFromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: EdgeInsets.all(hasAttachments ? 2 : 10),
        decoration: BoxDecoration(
          color: message.isFromUser ? Colors.purple : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hiển thị hình ảnh nếu có
            if (hasAttachments) ...[
              _buildAttachments(context),
              if (message.text.isNotEmpty) const SizedBox(height: 8),
            ],
            // Hiển thị text nếu có
            if (message.text.isNotEmpty) Text(message.text),
            const SizedBox(height: 4),
            // Thời gian
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                color: message.isFromUser ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments(BuildContext context) {
    return ChatImageGrid(
      message: message,
      key: ValueKey(message.id),
      onRetry: onRetry,
    );
  }
}
