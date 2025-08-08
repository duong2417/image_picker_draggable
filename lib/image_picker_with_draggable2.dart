import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker_with_draggable/draggable_sheet.dart';
// import 'package:core/core.dart';
// import 'package:user_interface/user_interface.dart';

import 'photo_manager.dart';
//////author: TRAN THANH TRA

class ImagePickerBottomsheet extends StatefulWidget {
  final VoidCallback onLoadMore;
  final List<File> files;
  final Function(double) sx;
  final Function(double) sy;
  final VoidCallback hideBottomSheet;
  final Function(List<File> files) callbackFile;

  final List<Uint8List> thumbnails;
  final double height;
  const ImagePickerBottomsheet({
    super.key,
    required this.height,
    required this.hideBottomSheet,
    required this.thumbnails,
    required this.onLoadMore,
    required this.callbackFile,
    required this.files,
    required this.sx,
    required this.sy,
  });

  @override
  State<ImagePickerBottomsheet> createState() => _ImagePickerBottomsheetState();
}

class _ImagePickerBottomsheetState extends State<ImagePickerBottomsheet> {
  final ScrollController scrollController = ScrollController();
  double? height;
  bool _isAnimatingHeight = false;
  bool _isClosing = false;
  List<File> filesData = [];
  _openCamera() {
    // MyBottomSheet.camera(
    //     context: context,
    //     sx: widget.sx,
    //     sy: widget.sy,
    //     onPicked: (e) {
    //       widget.callbackFile([File(e.path)]);
    //     });
  }

  // Future<void> _editImage(File image) async {
  //   final editedBytes = await Navigator.of(context).push(
  //     PageRouteBuilder(
  //       pageBuilder: (_, __, ___) => ImageEditor(
  //         image: image,
  //         outputFormat: OutputFormat.png,
  //       ),
  //       transitionsBuilder: (_, animation, __, child) {
  //         return SlideTransition(
  //           position: Tween<Offset>(
  //             begin: const Offset(1.0, 0.0),
  //             end: Offset.zero,
  //           ).animate(animation),
  //           child: child,
  //         );
  //       },
  //     ),
  //   );

  //   if (editedBytes != null && mounted) {
  //     final tempDir = await getTemporaryDirectory();
  //     final newFile = await File(
  //             '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png')
  //         .writeAsBytes(editedBytes);

  //     setState(() {
  //       filesData = [newFile];
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final minHeight = widget.height;
    final maxHeight = screenHeight * 0.9;

    return Stack(
      children: [
        DraggableSheet(
          maxHeight: maxHeight,
          height: widget.height,
          hideBottomSheet: () {
            widget.hideBottomSheet();
          },
          child: PhotoGridView(
            thumbnails: widget.thumbnails,
            files: widget.files,
            onLoadMore: widget.onLoadMore,
            onCameraTap: _openCamera,
            onAssetSelected: (selectedFiles) {
              if (selectedFiles.isNotEmpty) {
                debugPrint('Bạn đã chọn ${selectedFiles.first.path} file');
                setState(() {
                  filesData = selectedFiles;
                });

                // widget.files;
              } else {
                debugPrint('Không có ảnh nào được chọn.');
                setState(() {
                  filesData = [];
                });
              }
            },
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
          ),
        ),
        if (filesData.isNotEmpty)
          Positioned(
            bottom: widget.height / 2 - 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (filesData.length == 1)
                  SizedBox(
                    width: widget.sx(150),
                    child: ElevatedButton(
                      onPressed: () {
                        print('Chỉnh sửa ảnh: ${filesData.first.path}');
                        // _editImage(filesData.first);
                        // Gọi edit ở đây
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Chỉnh sửa"),
                    ),
                  ),
                SizedBox(
                  width: widget.sx(150),
                  child: ElevatedButton(
                    onPressed: () {
                      widget.callbackFile(filesData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Gửi"),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
