import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker_with_draggable/handler/attachment_picker_controller.dart';
import 'package:image_picker_with_draggable/utils/const.dart';
import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:image_picker_with_draggable/models/attachment_file.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart' hide Size;
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

///author: GetStream
extension StringX on String {
  /// returns the media type from the passed file name.
  MediaType? get mediaType {
    final mimeType = lookupMimeType(this);
    if (mimeType == null) return null;
    return MediaType.parse(mimeType);
  }
}

///author: GetStream
extension AssetEntityX on AssetEntity {
  /// Helper method to get the origin file with null safety
  Future<File?> getOriginFile() async {
    return await originFile;
  }

  /// Helper method to get cached file path in temp directory
  Future<String> getCachedFilePath(File originalFile) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/${originalFile.path.split('/').last}';
  }
}

///author: GetStream
extension ImagePickerX on AttachmentPickerController {
  Future<void> addAssetAttachment(AssetEntity asset) async {
    final mediaFile = await asset.getOriginFile();

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

        cachedFile = await File(
          await asset.getCachedFilePath(mediaFile),
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
      final image = await asset.getOriginFile();
      if (image != null) {
        final cachedFile = File(
          await asset.getCachedFilePath(image),
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

///author: GetStream
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

extension OriginalSizeX on Attachment {
  /// Returns the size of the attachment if it is an image or giffy.
  /// Otherwise, returns null.
  Size? get originalSize {
    // Return null if the attachment is not an image or giffy.
    if (type != AttachmentType.image && type != AttachmentType.giphy) {
      return null;
    }

    // Calculate size locally if the attachment is not uploaded yet.
    final file = this.file;
    if (file != null) {
      ImageInput? input;
      if (file.bytes != null) {
        input = MemoryInput(file.bytes!);
      } else if (file.path != null) {
        input = FileInput(File(file.path!));
      }

      // Return null if the file does not contain enough information.
      if (input == null) return null;

      try {
        final size = ImageSizeGetter.getSizeResult(input).size;
        if (size.needRotate) {
          return Size(size.height.toDouble(), size.width.toDouble());
        }
        return Size(size.width.toDouble(), size.height.toDouble());
      } catch (e, stk) {
        debugPrint('Error getting image size: $e\n$stk');
        return null;
      }
    }

    // Otherwise, use the size provided by the server.
    final width = originalWidth;
    final height = originalHeight;
    if (width == null || height == null) return null;
    return Size(width.toDouble(), height.toDouble());
  }
}

extension DurationX on Duration {
  String format() {
    final s = '$this'.split('.')[0].padLeft(8, '0');
    if (s.startsWith('00:')) {
      return s.replaceFirst('00:', '');
    }

    return s;
  }
}
