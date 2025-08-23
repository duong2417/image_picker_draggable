import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/common/buttons/back_button.dart';
import 'package:image_picker_with_draggable/common/dialog/error_dialog.dart';
import 'package:image_picker_with_draggable/edit_image/edit_image_screen.dart';
import 'package:image_picker_with_draggable/handler/attachment_handler.dart';
import 'package:image_picker_with_draggable/utils/helper.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class ImageFullScreen extends StatefulWidget {
  const ImageFullScreen({
    super.key,
    required this.onEditDone,
    required this.files,
    required this.currentIndex, //current page index
    required this.selectedAssets,
  });
  final Function(String) onEditDone;
  final List<AssetEntity> files;
  final int currentIndex;
  final Set<AssetEntity> selectedAssets;
  @override
  State<ImageFullScreen> createState() => _ImageFullScreenState();
}

class _ImageFullScreenState extends State<ImageFullScreen> {
  bool showAppBar = true;
  bool isHD = false;
  late final PageController pageController;
  Map<String, String> editedPaths = {};
  bool _selectedImage = false;
  late Set<AssetEntity> _selectedAssets;
  late List<AssetEntity> _files;
  late int _currentIndex;
  final handler = AttachmentHandler.instance;
  @override
  void initState() {
    super.initState();
    _files = widget.files;
    _currentIndex = widget.currentIndex;
    _selectedAssets = widget.selectedAssets;
    _selectedImage = _selectedAssets.contains(_files[_currentIndex]);
    pageController = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar:
          true, //cp ko thì khi show appbar, ảnh bị đẩy xuống (do appbar chiếm chỗ)
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: showAppBar ? 80 : 0,
          child: AppBar(
            centerTitle: false,
            leading: MyBackButton(
              color: Colors.white,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            // toolbarHeight: 80.h,
            backgroundColor: Colors.black.withOpacity(0.7),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            // title:
            //     showAmount
            //         ? (_files.isNotEmpty)
            //             ? Text(
            //               'Ảnh ${_currentIndex + 1}/${_files.length}',
            //               style: const TextStyle(color: Colors.white),
            //             )
            //             : null
            //         : null,
            actions: buildActions(
              onEditDone: widget.onEditDone,
              onCropImage: () async {
                final path = await onCropImage();
                if (path != null) {
                  widget.onEditDone(path); //update imgPickerBottomsheet
                }
              },
              onTapEditImage: () async {
                String? path;
                if (editedPaths.containsKey(_files[_currentIndex].id)) {
                  path = editedPaths[_files[_currentIndex].id]!;
                } else {
                  path = await assetEntityToPath(_files[_currentIndex]);
                }
                if (path == null) {
                  showError(context, 'Không tìm thấy ảnh');
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => DrawingRoomScreen(
                          filePath: path!,
                          isHD: isHD,
                          onEditDone: (editedImagePath) async {
                            widget.onEditDone(editedImagePath);
                          },
                        ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: toggleAppBar,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: pageController,
              itemCount: _files.length,
              onPageChanged: (index) {
                onPageChanged(index);
              },
              itemBuilder: (context, index) {
                final file = _files[index];
                // Kiểm tra xem có đường dẫn đã chỉnh sửa cho index này không
                if (editedPaths.containsKey(file.id)) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Center(
                      child: Hero(
                        tag: 'asset_${file.id}',
                        child: Image.file(
                          filterQuality:
                              isHD ? FilterQuality.high : FilterQuality.low,
                          File(editedPaths[file.id]!),
                          fit: BoxFit.contain,
                          width: MediaQuery.sizeOf(context).width,
                          height: MediaQuery.sizeOf(context).height,
                        ),
                      ),
                    ),
                  );
                } else {
                  return Hero(
                    tag: 'asset_${file.id}',
                    child: AssetEntityImage(
                      file,
                      // key: Key(file.id),
                      // filterQuality: FilterQuality.high,
                      isOriginal: isHD,
                      // thumbnailSize: const ThumbnailSize.square(200),
                      fit: BoxFit.cover,
                    ),
                  );
                }
              },
            ),

            // if (state.showAppBar)
            // AnimatedOpacity(
            //   //caption
            //   opacity: showAppBar ? 1 : 0,
            //   duration: const Duration(milliseconds: 300),
            //   child: Column(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Padding(
            //         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            //         child: InkWell(
            //           onTap: () {
            //             print('onTapCaption');
            //             // onTapCaption();
            //           },
            //           child: Container(
            //             width: double.infinity,
            //             padding: const EdgeInsets.symmetric(
            //               horizontal: 16,
            //               vertical: 10,
            //             ),
            //             decoration: BoxDecoration(
            //               gradient: const LinearGradient(
            //                 colors: [
            //                   Color.fromARGB(255, 61, 89, 104),
            //                   Colors.blueGrey,
            //                 ],
            //               ),
            //               borderRadius: BorderRadius.circular(50),
            //             ),
            //             child: Text(
            //               captions[_files[_currentIndex].id] ??
            //                   'Thêm chú thích...',
            //               style: appTextStyle.copyWith(color: Colors.white),
            //             ),
            //           ),
            //           // child: IgnorePointer(
            //           // child: AddCaptionField(
            //           //   readOnly: true,
            //           //   captionController: notifier.captionController,
            //           // ),
            //           // ),
            //         ),
            //       ),
            //       bottomBar,
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  void toggleAppBar() {}

  List<Widget> buildActions({
    required Function(String) onEditDone,
    required Function() onCropImage,
    required Function() onTapEditImage,
  }) {
    return [
      IconButton(
        icon: const Icon(Icons.crop, color: Colors.white),
        onPressed: () async {
          onCropImage();
        },
        tooltip: 'Cắt ảnh',
      ),
      // Nút chỉnh sửa ảnh với giao diện hiện đại
      IconButton(
        icon: Icon(Icons.edit, color: Colors.white),
        onPressed: () {
          // final path = _files[_currentIndex];
          onTapEditImage();
        },
        tooltip: 'Chỉnh sửa',
      ),
    ];
  }

  Future<String?> onCropImage() async {
    String? path;
    if (editedPaths.containsKey(_files[_currentIndex].id)) {
      path = editedPaths[_files[_currentIndex].id]!;
    } else {
      path = await assetEntityToPath(_files[_currentIndex]);
    }
    if (path == null) {
      showError(context, 'Không tìm thấy ảnh');
      return null;
    }
    final file = await handler.cropImage(path);
    if (file != null) {
      editedPaths[_files[_currentIndex].id] = file.path;
      updateState();
    }
    return file?.path;
  }

  void onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _selectedImage = _selectedAssets.contains(_files[index]);
    });
  }

  void updateState() {
    setState(() {});
  }
}
