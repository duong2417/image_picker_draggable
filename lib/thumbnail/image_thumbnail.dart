import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/models/attachment_file.dart';

class LocalImageAttachment extends StatelessWidget {
  const LocalImageAttachment({super.key, required this.file});
  final AttachmentFile file;

  @override
  Widget build(BuildContext context) {
    final bytes = file.bytes;
    if (bytes != null) {
      return Image.memory(bytes, width: 100, height: 100, fit: BoxFit.cover);
    }

    final path = file.path;
    if (path != null) {
      return Image.file(File(path), width: 100, height: 100, fit: BoxFit.cover);
    }
    return const SizedBox(
      width: 100,
      height: 100,
      child: Center(
        child: Text('No Image', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
