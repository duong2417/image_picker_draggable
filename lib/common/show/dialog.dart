import 'package:flutter/material.dart';

class CommonDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? content,
    Widget? contentWidget,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
    Color? primaryColor,
    bool showCancelButton = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: contentWidget ?? 
              (content != null 
                  ? Text(
                      content,
                      style: const TextStyle(fontSize: 16),
                    )
                  : null),
          actions: [
            if (showCancelButton)
              TextButton(
                onPressed: onCancel ?? () => Navigator.of(context).pop(),
                child: Text(
                  cancelText ?? 'Hủy',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            if (confirmText != null)
              ElevatedButton(
                onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor ?? Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  confirmText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Dialog thông báo đơn giản
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return show(
      context: context,
      title: title,
      content: message,
      confirmText: buttonText ?? 'OK',
      showCancelButton: false,
      onConfirm: onPressed ?? () => Navigator.of(context).pop(),
    );
  }

  // Dialog xác nhận
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
  }) {
    return show<bool>(
      context: context,
      title: title,
      content: message,
      confirmText: confirmText ?? 'Xác nhận',
      cancelText: cancelText ?? 'Hủy',
      primaryColor: confirmColor ?? Colors.red,
      onConfirm: () => Navigator.of(context).pop(true),
      onCancel: () => Navigator.of(context).pop(false),
    );
  }

  // Dialog cảnh báo
  static Future<void> showWarning({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
  }) {
    return showInfo(
      context: context,
      title: title,
      message: message,
      buttonText: buttonText ?? 'Đã hiểu',
    );
  }

  // Dialog lỗi
  static Future<void> showError({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
  }) {
    return show(
      context: context,
      title: title,
      content: message,
      confirmText: buttonText ?? 'Đóng',
      showCancelButton: false,
      primaryColor: Colors.red,
    );
  }

  // Dialog với input text
  static Future<String?> showTextInput({
    required BuildContext context,
    required String title,
    String? hint,
    String? initialValue,
    String? confirmText,
    String? cancelText,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    final TextEditingController controller = TextEditingController(text: initialValue);
    
    return show<String>(
      context: context,
      title: title,
      contentWidget: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        autofocus: true,
      ),
      confirmText: confirmText ?? 'OK',
      cancelText: cancelText ?? 'Hủy',
      onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
      onCancel: () => Navigator.of(context).pop(),
    );
  }

  // Dialog loading
  static void showLoading({
    required BuildContext context,
    String? message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Đóng loading dialog
  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }
}