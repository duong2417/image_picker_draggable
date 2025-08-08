import 'dart:io';
import 'dart:math' as math;

import 'package:http_parser/http_parser.dart';
import 'package:image_picker_with_draggable/attachment_picker/attachment_picker_controller.dart';
import 'package:image_picker_with_draggable/const.dart';
import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:image_picker_with_draggable/models/attachment_file.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

extension StringX on String {
  /// returns the media type from the passed file name.
  MediaType? get mediaType {
    final mimeType = lookupMimeType(this);
    if (mimeType == null) return null;
    return MediaType.parse(mimeType);
  }
}

extension ImagePickerX on AttachmentPickerController {
  Future<void> addAssetAttachment(AssetEntity asset) async {
    final mediaFile = await asset.originFile;

    if (mediaFile == null) return;

    var cachedFile = mediaFile;

    final type = asset.type;
    if (type == AssetType.image) {
      // Resize image if it's resolution is greater than the
      // [maxCDNImageResolution].
      final imageResolution = asset.width * asset.height;
      if (imageResolution > maxCDNImageResolution) {
        final aspect = imageResolution / maxCDNImageResolution;
        final updatedSize = asset.size / (math.sqrt(aspect));
        final resizedImage = await asset.thumbnailDataWithSize(
          ThumbnailSize(updatedSize.width.floor(), updatedSize.height.floor()),
          quality: 70,
        );

        final tempDir = await getTemporaryDirectory();
        cachedFile = await File(
          '${tempDir.path}/${mediaFile.path.split('/').last}',
        ).create().then((it) => it.writeAsBytes(resizedImage!));
      }
    }

    final file = AttachmentFile(
      path: cachedFile.path,
      size: await cachedFile.length(),
      bytes: cachedFile.readAsBytesSync(),
    );

    final extraDataMap = <String, Object>{};

    final mimeType = file.mediaType?.mimeType;

    if (mimeType != null) {
      extraDataMap['mime_type'] = mimeType;
    }

    extraDataMap['file_size'] = file.size!;

    final attachment = Attachment(
      id: asset.id,
      file: file,
      type: asset.type.toAttachmentType(),
      extraData: extraDataMap,
    );

    return addSingleAttachment(attachment);
  }

  Future<void> removeAssetAttachment(AssetEntity asset) async {
    if (asset.type == AssetType.image) {
      final image = await asset.originFile;
      if (image != null) {
        final tempDir = await getTemporaryDirectory();
        final cachedFile = File(
          '${tempDir.path}/${image.path.split('/').last}',
        );
        if (cachedFile.existsSync()) {
          cachedFile.deleteSync();
        }
      }
    }
    return removeAttachmentById(asset.id);
  }
}

extension AssetTypeX on AssetType {
  String toAttachmentType() {
    switch (this) {
      case AssetType.image:
        return 'image';
      case AssetType.video:
        return 'video';
      case AssetType.audio:
        return 'audio';
      case AssetType.other:
        return 'file';
    }
  }
}

/// {@template attachmentType}
/// A type of attachment that determines how the attachment is displayed and
/// handled by the system.
///
/// It can be one of the backend-specified types (image, file, giphy, video,
/// audio, voiceRecording) or application custom types like urlPreview.
/// {@endtemplate}
extension type const AttachmentType(String rawType) implements String {
  /// Backend specified types.
  static const image = AttachmentType('image');
  static const file = AttachmentType('file');
  static const giphy = AttachmentType('giphy');
  static const video = AttachmentType('video');
  static const audio = AttachmentType('audio');
  static const voiceRecording = AttachmentType('voiceRecording');

  /// Application custom types.
  static const urlPreview = AttachmentType('url_preview');

  /// Create a new instance from a json string.
  static AttachmentType? fromJson(String? rawType) {
    if (rawType == null) return null;
    return AttachmentType(rawType);
  }

  /// Serialize to json string.
  static String? toJson(String? type) => type;
}
