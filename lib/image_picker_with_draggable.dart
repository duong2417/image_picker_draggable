import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/attachment_picker/attachment_picker_controller.dart';
import 'package:image_picker_with_draggable/attachment_picker/options/gallery_picker.dart';
import 'package:image_picker_with_draggable/draggable_sheet.dart';
import 'package:image_picker_with_draggable/utils/extensions.dart';

import 'models/attachment.dart';
import 'models/attachment_picker.dart';

class ImagePickerBottomsheet extends StatefulWidget {
  const ImagePickerBottomsheet({
    super.key,
    required this.height,
    required this.hideBottomSheet,
    this.initialAttachments,
  });
  final double height;
  final VoidCallback hideBottomSheet;
  final List<Attachment>? initialAttachments;

  @override
  State<ImagePickerBottomsheet> createState() => _ImagePickerBottomsheetState();
}

class _ImagePickerBottomsheetState extends State<ImagePickerBottomsheet> {
  double? height;
  bool _isAnimatingHeight = false;
  bool _isClosing = false;
  late final AttachmentPickerController _controller;
  late final ScrollController scrollController;
  @override
  void initState() {
    super.initState();
    _controller = AttachmentPickerController(
      initialAttachments: widget.initialAttachments,
    );
    scrollController = ScrollController();
  }

  @override
  void dispose() {
    scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final minHeight = widget.height;
    final maxHeight = screenHeight * 0.9;
    return DraggableSheet(
      height: widget.height,
      maxHeight: maxHeight,
      hideBottomSheet: () {
        widget.hideBottomSheet();
      },
      child: ValueListenableBuilder<AttachmentPickerValue>(
        valueListenable: _controller,
        builder: (context, atms, _) {
          final attachment = _controller.value.attachments;
          final selectedIds = attachment.map((it) => it.id);
          return GalleryPicker(
            selectedMediaItems: selectedIds,
            onTap: (media) async {
              debugPrint('Tapped on media: ${media.id}');
              try {
                if (selectedIds.contains(media.id)) {
                  return await _controller.removeAssetAttachment(media);
                }
                return await _controller.addAssetAttachment(media);
              } catch (e, stk) {
                // if (onError != null) return onError.call(e, stk);
                debugPrint('Error adding/removing attachment: $e');
                rethrow;
              }
            },
            scrollController: scrollController,
            onScrollDownAtTop: () {
              final currentHeight = height ?? minHeight;

              if (_isAnimatingHeight || _isClosing) return;

              // Đang ở maxHeight thì chỉ thu nhỏ
              if ((currentHeight - maxHeight).abs() < 1) {
                _isAnimatingHeight = true;
                setState(() {
                  height = minHeight;
                });
                // Reset flag sau 300ms
                Future.delayed(const Duration(milliseconds: 300), () {
                  _isAnimatingHeight = false;
                });
              }
              // Đang ở minHeight thì mới đóng
              else if ((currentHeight - minHeight).abs() < 1) {
                _isClosing = true;
                Future.delayed(const Duration(milliseconds: 200), () {
                  widget.hideBottomSheet();
                  _isClosing = false;
                });
              }
            },
          );
        },
      ),
    );
  }
}
