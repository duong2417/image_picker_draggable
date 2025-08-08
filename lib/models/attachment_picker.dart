import 'attachment.dart';

class AttachmentPickerValue {
  const AttachmentPickerValue({this.attachments = const []});

  final List<Attachment> attachments;

  AttachmentPickerValue copyWith({List<Attachment>? attachments}) {
    return AttachmentPickerValue(attachments: attachments ?? this.attachments);
  }
}
