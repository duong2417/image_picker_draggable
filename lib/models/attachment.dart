import 'package:equatable/equatable.dart';
import 'package:image_picker_with_draggable/models/attachment_file.dart';
import 'package:image_picker_with_draggable/models/upload_state.dart';
import 'package:image_picker_with_draggable/utils/extensions.dart';
import 'package:uuid/uuid.dart';

class Attachment extends Equatable {
  Attachment({
    String? id,
    String? name,
    String? type,
    this.file,
    this.url,
    this.thumbnailUrl,
    this.size,
    this.createdAt,
    Map<String, Object?> extraData = const {},
    this.uploadState = const UploadState.preparing(),
  }) : id = id ?? const Uuid().v4(),
       _type = switch (type) {
         String() => AttachmentType(type),
         _ => null,
       },
       name = name ?? file?.name,
       localUri = file?.path != null ? Uri.parse(file!.path!) : null,
       // For backwards compatibility,
       // set 'file_size', 'mime_type' in [extraData].
       extraData = {
         ...extraData,
         if (file?.size != null) 'file_size': file?.size,
         if (file?.mediaType != null) 'mime_type': file?.mediaType?.mimeType,
       };
  final String id;
  final String? name;
  final String? url;
  final String? thumbnailUrl;
  final int? size;
  final DateTime? createdAt;
  final AttachmentFile? file;
  final Map<String, Object?> extraData;
  final UploadState uploadState; //default value: success
  final AttachmentType? _type;
  final Uri? localUri;

  int? get fileSize => extraData['file_size'] as int?;
  String? get mimeType => extraData['mime_type'] as String?;
  String? get rawType => _type;

  @override
  List<Object?> get props => [
    id,
    name,
    url,
    thumbnailUrl,
    size,
    createdAt,
    file,
    extraData,
    fileSize,
    uploadState,
  ];

  Attachment copyWith({
    String? id,
    String? name,
    String? url,
    String? thumbnailUrl,
    int? size,
    DateTime? createdAt,
    AttachmentFile? file,
    Map<String, Object?>? extraData,
    UploadState? uploadState,
  }) {
    return Attachment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: _type?.rawType,
      file: file ?? this.file,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      extraData: extraData ?? this.extraData,
      uploadState: uploadState ?? this.uploadState,
    );
  }
}
