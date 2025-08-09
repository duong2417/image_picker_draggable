import 'package:equatable/equatable.dart';
import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:uuid/uuid.dart';

enum MessageType {
  text,
  image,
  mixed, // text + images
}

class Message extends Equatable {
  const Message({
    required this.id,
    required this.text,
    required this.attachments,
    required this.timestamp,
    required this.type,
    this.isFromUser = true,
  });

  factory Message.create({
    String? text,
    List<Attachment>? attachments,
    bool isFromUser = true,
  }) {
    final messageText = text ?? '';
    final messageAttachments = attachments ?? [];
    
    MessageType type;
    if (messageAttachments.isNotEmpty && messageText.isNotEmpty) {
      type = MessageType.mixed;
    } else if (messageAttachments.isNotEmpty) {
      type = MessageType.image;
    } else {
      type = MessageType.text;
    }

    return Message(
      id: const Uuid().v4(),
      text: messageText,
      attachments: messageAttachments,
      timestamp: DateTime.now(),
      type: type,
      isFromUser: isFromUser,
    );
  }

  final String id;
  final String text;
  final List<Attachment> attachments;
  final DateTime timestamp;
  final MessageType type;
  final bool isFromUser;

  @override
  List<Object?> get props => [
        id,
        text,
        attachments,
        timestamp,
        type,
        isFromUser,
      ];

  Message copyWith({
    String? id,
    String? text,
    List<Attachment>? attachments,
    DateTime? timestamp,
    MessageType? type,
    bool? isFromUser,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isFromUser: isFromUser ?? this.isFromUser,
    );
  }
}
