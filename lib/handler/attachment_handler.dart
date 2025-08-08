import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:image_picker_with_draggable/models/attachment_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

abstract class AttachmentHandlerBase {
  /// Pick an image from the device.
  Future<Attachment?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) {
    throw UnimplementedError('pickImage is not implemented');
  }

  /// Save an attachment file to a temporary location.
  Future<String> saveAttachmentFile({required AttachmentFile attachmentFile}) {
    throw UnimplementedError('saveAttachmentFile is not implemented');
  }
}

class AttachmentHandler extends AttachmentHandlerBase {
  static final AttachmentHandler _instance = AttachmentHandler._();

  AttachmentHandler._();

  static AttachmentHandler get instance => _instance;

  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = Uuid();

  @override
  Future<Attachment?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        preferredCameraDevice: preferredCameraDevice,
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      final fileSize = await file.length();
      final fileName = path.basename(pickedFile.path);

      return Attachment(
        id: _uuid.v4(),
        type: 'image',
        file: AttachmentFile(
          path: pickedFile.path,
          name: fileName,
          bytes: await file.readAsBytes(),
          size: fileSize,
        ),
        name: fileName,
      );
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  @override
  Future<String> saveAttachmentFile({
    required AttachmentFile attachmentFile,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = attachmentFile.name ?? '${_uuid.v4()}.tmp';
      final String filePath = path.join(tempDir.path, fileName);

      final File file = File(filePath);

      if (attachmentFile.bytes != null) {
        await file.writeAsBytes(attachmentFile.bytes!);
      } else if (attachmentFile.path != null) {
        final sourceFile = File(attachmentFile.path!);
        if (await sourceFile.exists()) {
          await sourceFile.copy(filePath);
        } else {
          throw Exception('Source file does not exist: ${attachmentFile.path}');
        }
      } else {
        throw Exception('No file data or path provided');
      }

      return filePath;
    } catch (e) {
      print('Error saving attachment file: $e');
      rethrow;
    }
  }
}
