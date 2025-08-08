import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/image_picker_with_draggable.dart';

Future<T?> showAtttachmentPickerBottomSheet<T>({
  required BuildContext context,
  required double height,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return ImagePickerBottomsheet(height: height);
    },
  );
}