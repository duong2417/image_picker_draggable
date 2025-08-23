import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:image_picker_with_draggable/models/attachment_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'dart:ui' as ui;

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

  ////EDIT IMAGE
  Future<CroppedFile?> cropImage(String pickedFile) async {
    throw UnimplementedError('cropImage is not implemented');
  }

  Future<String> captureWidget(
    BuildContext context, {
    // required int index,
    required GlobalKey globalKey,
    required double pixelRatio,
  }) async {
    throw UnimplementedError('captureWidget is not implemented');
  }

  Future<String> saveImage(Uint8List bytes) async {
    throw UnimplementedError('saveImage is not implemented');
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

  /////EDIT IMAGE
  @override
  Future<CroppedFile?> cropImage(String pickedFile) async {
    CroppedFile? croppedFile;
    croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          // backgroundColor: Colors.blue,
          activeControlsWidgetColor: Colors.blue, //cp: bộ tools ở dưới
          toolbarTitle: 'Cắt ảnh',
          statusBarColor: Colors.blue,
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          cropFrameColor: Colors.blue,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Cắt ảnh'),
      ],
    );
    return croppedFile;
  }

  @override
  Future<String> captureWidget(
    BuildContext context, {
    // required int index,
    required GlobalKey globalKey,
    required double pixelRatio,
  }) async {
    Uint8List? pngBytes;
    ui.Image? image;
    final RenderRepaintBoundary boundary =
        globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    //high resolution img: https://stackoverflow.com/questions/67239184/high-resolution-image-from-flutter-widget
    image = await boundary.toImage(pixelRatio: pixelRatio); //1.5
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    pngBytes = byteData!.buffer.asUint8List();
    // XFile file = XFile.fromData(pngBytes);
    String path = await saveImage(pngBytes);
    return path;
  }

  @override
  Future<String> saveImage(Uint8List bytes) async {
    // Get the directory for the app's documents directory.
    final directory = await getApplicationDocumentsDirectory();

    // Generate a unique file name.
    String filePath =
        '${directory.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Write the bytes to the file.
    await File(filePath).writeAsBytes(bytes);

    // Return the file path.
    return filePath;
  }
}
