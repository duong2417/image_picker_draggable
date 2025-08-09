import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/gallery_attachment.dart';
import 'package:image_picker_with_draggable/models/message.dart';
import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:image_picker_with_draggable/thumbnail/image_thumbnail.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final galleryAttachments = message.attachments;
    // final galleryAttachments =
    //     message.attachments
    //         .where(
    //           (attachment) =>
    //               attachment.type == AttachmentType.image ||
    //               attachment.type == AttachmentType.video,
    //         )
    //         .toList();
    // return StreamGalleryAttachment(
    //   attachments: message.attachments,
    //   message: message,
    //   itemBuilder: (BuildContext context, int index) {
    //     final attachment = galleryAttachments[index];
    //     return InkWell(
    //       onTap: () {
    //         // Handle attachment tap if needed
    //       },
    //       child: ImageThumbnail(file: attachment.file!),
    //     );
    //   },
    // );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isFromUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
        children: [
          if (!message.isFromUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isFromUser ? Colors.blue[600] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hiển thị hình ảnh nếu có
                  if (message.attachments.isNotEmpty) ...[
                    _buildAttachments(galleryAttachments),
                    if (message.text.isNotEmpty) const SizedBox(height: 8),
                  ],
                  // Hiển thị text nếu có
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: TextStyle(
                        color:
                            message.isFromUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Thời gian
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color:
                          message.isFromUser
                              ? Colors.white70
                              : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isFromUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachments(List<Attachment> galleryAttachments) {
    return StreamGalleryAttachment(
      // constraints: BoxConstraints.expand(height: 100),
      constraints: BoxConstraints.tightFor(width: 256, height: 195),
      attachments: galleryAttachments,
      message: message,
      itemBuilder: (BuildContext context, int index) {
        final attachment = galleryAttachments[index];
        return InkWell(
          onTap: () {
            // Handle attachment tap if needed
          },
          child: LocalImageAttachment(file: attachment.file!),
        );
      },
    );
    // if (message.attachments.length == 1) {
    //   return _buildSingleImage(message.attachments.first);
    // } else {
    //   return _buildMultipleImages();
    // }
  }

  Widget _buildSingleImage(Attachment attachment) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
        child: _buildImageWidget(attachment),
      ),
    );
  }

  Widget _buildMultipleImages() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: message.attachments.length,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImageWidget(message.attachments[index]),
          );
        },
      ),
    );
  }

  Widget _buildImageWidget(Attachment attachment) {
    if (attachment.file?.path != null) {
      // Hiển thị file local
      return Image.file(
        File(attachment.file!.path!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.red),
          );
        },
      );
    } else if (attachment.url != null) {
      // Hiển thị ảnh từ URL
      return Image.network(
        attachment.url!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.red),
          );
        },
      );
    } else {
      // Placeholder khi không có ảnh
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }
  }
}
