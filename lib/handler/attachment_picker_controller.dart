import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/utils/const.dart';
import 'package:image_picker_with_draggable/handler/attachment_handler.dart';
import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:image_picker_with_draggable/models/attachment_file.dart';
import 'package:image_picker_with_draggable/models/attachment_picker.dart';

class AttachmentPickerController extends ValueNotifier<AttachmentPickerValue> {
  AttachmentPickerController({
    this.initialAttachments, // Danh sách attachment ban đầu (nếu có)
    this.maxAttachmentSize =
        kDefaultMaxAttachmentSize, // Kích thước tối đa mỗi file
    this.maxAttachmentCount =
        kDefaultMaxAttachmentCount, // Số lượng file tối đa
  }) : assert(
         (initialAttachments?.length ?? 0) <= maxAttachmentCount,
         '''The initial attachments count must be less than or equal to maxAttachmentCount''',
       ),
       super(
         AttachmentPickerValue(attachments: initialAttachments ?? const []),
       );

  /// The max attachment size allowed in bytes.
  final int maxAttachmentSize;

  /// The max attachment count allowed.
  final int maxAttachmentCount;

  /// The initial attachments.
  final List<Attachment>? initialAttachments;

  @override
  set value(AttachmentPickerValue newValue) {
    // Kiểm tra giới hạn số lượng attachment trước khi cập nhật giá trị
    if (newValue.attachments.length > maxAttachmentCount) {
      throw ArgumentError(
        'The maximum number of attachments is $maxAttachmentCount.',
      );
    }
    super.value = newValue;
  }

  /// Removes an attachment from the picker.
  void removeAttachment(Attachment attachment) {
    value = value.copyWith(
      attachments:
          value.attachments.where((a) => a.id != attachment.id).toList(),
    );
  }

  void removeAttachmentById(String attachmentId) {
    final attachment = value.attachments.firstWhereOrNull(
      (attachment) => attachment.id == attachmentId,
    );

    // Nếu không tìm thấy attachment với ID tương ứng, không làm gì cả
    if (attachment == null) return;

    removeAttachment(attachment);
  }

  Future<void> addSingleAttachment(Attachment attachment) async {
    return addAttachment([attachment]);
  }

  Future<void> addAttachment(List<Attachment> attachments) async {
    // Kiểm tra giới hạn số lượng attachment
    final totalCount = value.attachments.length + attachments.length;
    if (totalCount > maxAttachmentCount) {
      throw ArgumentError(
        'Cannot add ${attachments.length} attachments. '
        'Current count: ${value.attachments.length}, '
        'Maximum allowed: $maxAttachmentCount',
      );
    }

    final processedAttachments = <Attachment>[];

    // Xử lý từng attachment trong danh sách
    for (final attachment in attachments) {
      // Đảm bảo attachment phải có thông tin kích thước file
      assert(attachment.fileSize != null, 'Attachment fileSize cannot be null');

      // Kiểm tra kích thước file có vượt quá giới hạn cho phép không
      if (attachment.fileSize! > maxAttachmentSize) {
        throw ArgumentError(
          'The size of the attachment "${attachment.name}" is ${attachment.fileSize} bytes, '
          'but the maximum size allowed is $maxAttachmentSize bytes.',
        );
      }

      final file = attachment.file;
      final uploadState = attachment.uploadState;

      // Không cần cache nếu file đã được upload thành công hoặc đang chạy trên web
      if (file == null || uploadState.isSuccess) {
        processedAttachments.add(attachment);
      } else {
        // Cache the attachment in a temporary file.
        // Lưu file vào cache tạm thời để sử dụng sau này
        final tempFilePath = await _saveToCache(file);

        // Thêm attachment với đường dẫn file cache mới
        processedAttachments.add(
          attachment.copyWith(file: file.copyWith(path: tempFilePath)),
        );
      }
    }

    // Cập nhật danh sách attachment với tất cả các attachment đã xử lý
    value = value.copyWith(
      attachments: [...value.attachments, ...processedAttachments],
    );
  }

  /// Lưu file attachment vào cache tạm thời
  /// Trả về đường dẫn của file đã được cache
  Future<String> _saveToCache(AttachmentFile file) async {
    //lưu file vào thư mục cache của ứng dụng
    return AttachmentHandler.instance.saveAttachmentFile(attachmentFile: file);
  }

  void clearAttachments() {
    value = value.copyWith(attachments: []);
  }
}
