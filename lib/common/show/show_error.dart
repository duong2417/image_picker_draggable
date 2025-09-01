import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/common/show/dialog.dart';
import 'package:image_picker_with_draggable/main.dart';

showErrorDialog([String? message, BuildContext? context]) {
  final _ct = context ?? globalAppContext!;
  CommonDialog.show(
    context: _ct,
    title: 'Lỗi',
    content: message ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.',
    confirmText: 'OK',
    onConfirm: () {
      Navigator.of(_ct).pop();
    },
  );
}
