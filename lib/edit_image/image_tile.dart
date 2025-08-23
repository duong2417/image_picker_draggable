import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/common/buttons/pick_image_circle_button.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'dart:io';

//each img trong ds assets hiện trong bottomsheet
class ImageTile extends StatefulWidget {
  const ImageTile({
    super.key,
    required this.asset,
    // required this.assets,
    required this.selectedAssets,
    required this.onPickImage,
    // required this.bar,
    required this.onTap,
    required this.editedImagePath,
    required this.index,
    required this.caption,
  });
  final AssetEntity asset;
  // final List<AssetEntity> assets;
  final Iterable<String> selectedAssets;
  final Function(AssetEntity) onPickImage;
  // final BottomBarPickImage bar;
  final Function(AssetEntity) onTap;
  final int index;
  final String? editedImagePath;
  final String? caption;
  @override
  State<ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<ImageTile> {
  // late final FileHandler fileHandler;
  @override
  void initState() {
    super.initState();
    // fileHandler = FileHandler();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;//assets[widget.index];
    final isSelected = widget.selectedAssets.contains(asset.id);
    return Stack(
      children: [
        // Hiển thị ảnh đã chỉnh sửa nếu có, nếu không hiển thị ảnh gốc
        Positioned.fill(
          child: Hero(
            tag: 'asset_${asset.id}',
            child:
                widget.editedImagePath != null
                    ? Image.file(
                      File(widget.editedImagePath!),
                      fit: BoxFit.cover,
                    )
                    : AssetEntityImage(
                      asset,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(200),
                      fit: BoxFit.cover,
                    ),
          ),
        ),

        // Vùng nhấn để xem ảnh toàn màn hình
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                widget.onTap(asset); //addToSelectedAssets
                // fileHandler.openFullScreenImage(
                //   index: widget.index,
                //   files: widget.assets,
                //   editedImagePaths: widget.editedImagePaths,
                //   bottomNavigationBar: widget.bar,
                //   // actions: [],
                //   onEditDone: (path) {
                //     print('onEditDone trong image_tile: $path');
                //     // Kiểm tra xem có kết quả trả về và đã chỉnh sửa ảnh không
                //     // Cập nhật đường dẫn ảnh đã chỉnh sửa
                //     setState(() {
                //       editedImagePath = path;
                //     });
                //     widget.onEdited(path, widget.index);
                //   },
                // );
              },
            ),
          ),
        ),

        // Biểu tượng chọn ảnh (hình tròn ở góc phải)
        Positioned(
          top: 5,
          right: 5,
          child: PickImageCircleButton(
            selected: isSelected,
            currentIndex: widget.selectedAssets.toList().indexOf(asset.id),
            onPickImage: (asset) {
              widget.onPickImage(asset);
            },
            asset: asset,
          ),
        ),

        // Hiển thị biểu tượng đã chỉnh sửa nếu ảnh đã được chỉnh sửa
        if (widget.editedImagePath != null || widget.caption != null)
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                // borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.caption ?? 'Đã sửa',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
