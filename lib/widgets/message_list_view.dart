import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:image_picker_with_draggable/models/message.dart';
import 'package:image_picker_with_draggable/widgets/message_bubble.dart';

class MessageListView extends StatelessWidget {
  const MessageListView({
    super.key,
    required this.messages,
    this.scrollController,
    this.onRetry,
  });

  final List<Message> messages;
  final ScrollController? scrollController;
  // Callback for retrying a failed upload for a specific message + attachment.
  final void Function(Message message, Attachment attachment)? onRetry;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có tin nhắn nào',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      reverse: true, // Tin nhắn mới nhất ở dưới cùng
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: MessageBubble(
            message: message,
            onRetry: onRetry == null
                ? null
                : (attachment) => onRetry!(message, attachment),
          ),
        );
      },
    );
  }
}
