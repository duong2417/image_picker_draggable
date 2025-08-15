import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/common/empty_widget.dart';
import 'package:image_picker_with_draggable/const.dart';
import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:image_picker_with_draggable/models/message.dart';
import 'dart:io';
import 'dart:async';

import 'package:image_picker_with_draggable/models/upload_state.dart';
import 'package:image_picker_with_draggable/utils/extensions.dart';

class ChatImageGrid extends StatefulWidget {
  final Message message;
  final void Function(Attachment attachment)? onRetry;
  const ChatImageGrid({super.key, required this.message, this.onRetry});

  @override
  State<ChatImageGrid> createState() => _ChatImageGridState();
}

class _ChatImageGridState extends State<ChatImageGrid> {
  late final GlobalKey _globalKey;
  List<ImageDimension> _imageDimensions = [];
  late List<Attachment> _attachments;
  @override
  void initState() {
    super.initState();
    _attachments =
        widget.message.attachments
            .where((attachment) => attachment.type == AttachmentType.image)
            .toList();
    _globalKey = GlobalKey();
    _loadImageDimensions();
  }

  @override
  void didUpdateWidget(covariant ChatImageGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep attachments in sync to get latest uploadState
    final newAttachments = widget.message.attachments
        .where((attachment) => attachment.type == AttachmentType.image)
        .toList();
    // If count or ids changed, reload dimensions
    final needReload = newAttachments.length != _attachments.length ||
        !_sameIds(newAttachments, _attachments);
    _attachments = newAttachments;
    if (needReload) {
      _imageDimensions = [];
      _loadImageDimensions();
    } else {
      // still trigger rebuild to reflect new upload state overlays
      setState(() {});
    }
  }

  bool _sameIds(List<Attachment> a, List<Attachment> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _loadImageDimensions() async {
    List<ImageDimension> dimensions = [];
    for (var file in _attachments) {
      try {
        // Đối với ảnh, lấy kích thước thực
        final image = Image.file(File(file.file!.path!));
        final completer = Completer<ImageDimension>();

        image.image
            .resolve(const ImageConfiguration())
            .addListener(
              ImageStreamListener((info, _) {
                final width = info.image.width.toDouble();
                final height = info.image.height.toDouble();
                final aspectRatio = width / height;
                completer.complete(
                  ImageDimension(
                    file.file!.path!,
                    aspectRatio,
                    aspectRatio >= 1.0,
                    width: width,
                    height: height,
                  ),
                );
              }),
            );

        dimensions.add(await completer.future);
      } catch (e) {
        // Nếu không thể lấy kích thước, sử dụng giá trị mặc định
        dimensions.add(ImageDimension(file.file!.path!, 1.0, true));
        print('Không thể lấy kích thước hình ảnh: $e');
      }
    }

    if (mounted) {
      setState(() {
        _imageDimensions = dimensions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nếu không có ảnh
    if (_attachments.isEmpty) {
      return const Empty();
    }
    return KeyedSubtree(key: _globalKey, child: _buildGridByCount());
  }

  Widget _buildGridByCount() {
    // Xác định bố cục theo số lượng ảnh
    switch (_attachments.length) {
      case 1:
        return _buildSingleImage();
      case 2:
        return _buildTwoImages();
      case 3:
        return _buildThreeImages();
      case 4:
        return _buildFourImages();
      default:
        return _buildMultipleImages();
    }
  }

  Widget _buildImageItem(
    Attachment file,
    double width,
    double height, {
    BorderRadius? customBorderRadius,
  }) {
    if (file.file?.path == null) {
      return const SizedBox.shrink();
    }
    final index = _attachments.indexWhere((element) => element.id == file.id);
    if (index < 0) {
      return const SizedBox.shrink();
    }

    final upload = file.uploadState;
    final isFailed = upload.isFailed;

    return ClipRRect(
      borderRadius:
          customBorderRadius ?? BorderRadius.circular(borderRadiusBubble),
      child: GestureDetector(
        onTap: () {
          print('Tapped on image: ${file.file!.path}');
          // Mở ảnh trong chế độ xem đầy đủ
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Hero(
              tag: 'image_${file.id}',
              child: Image.file(
                File(file.file!.path!),
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
            // Overlays for upload states
            if (upload.isPreparing)
              _buildOverlay(width, height,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )),
            if (upload.isInProgress)
              _buildProgressOverlay(width, height, upload as InProgress),
            if (isFailed)
              _buildFailedOverlay(width, height, onRetry: () {
                widget.onRetry?.call(file);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(double w, double h, {required Widget child}) {
    return Container(
      width: w,
      height: h,
      color: Colors.black.withOpacity(0.25),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _buildProgressOverlay(double w, double h, InProgress p) {
    final percent = p.total == 0 ? 0.0 : p.uploaded / p.total;
    return _buildOverlay(
      w,
      h,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: w * 0.6,
            child: LinearProgressIndicator(value: percent),
          ),
          const SizedBox(height: 6),
          Text('${(percent * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildFailedOverlay(double w, double h, {VoidCallback? onRetry}) {
    return _buildOverlay(
      w,
      h,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  // Hiển thị 1 ảnh
  Widget _buildSingleImage() {
    // Nếu chưa có thông tin về kích thước ảnh
    if (_imageDimensions.isEmpty) {
      return _buildImageItem(
        _attachments[0],
        widthSingleImage,
        heightSingleImage,
      );
    }

    final imageInfo = _imageDimensions[0];
    double imageWidth;
    double imageHeight;
    // return _buildImageItem(widget.imageUrls[0], imageWidth, imageHeight);

    // Điều chỉnh kích thước dựa trên tỉ lệ ảnh
    if (imageInfo.isLandscape) {
      imageWidth = MediaQuery.sizeOf(context).width * 0.9;
      imageHeight = imageWidth / imageInfo.aspectRatio;
      // Ảnh ngang
      // imageHeight = imageWidth / imageInfo.aspectRatio;
      // Đảm bảo không quá nhỏ
      // if (imageHeight < heightSingleImage * 0.7) {
      //   imageHeight = heightSingleImage * 0.7;
      // }
    } else {
      imageHeight = heightSingleImage;
      imageWidth = imageHeight * imageInfo.aspectRatio;
      // Ảnh dọc
      // imageWidth = imageHeight * imageInfo.aspectRatio;
      // // Đảm bảo không quá nhỏ
      // if (imageWidth < widthSingleImage * 0.7) {
      //   imageWidth = widthSingleImage * 0.7;
      // }
    }

    // Giới hạn kích thước tối đa
    // if (imageWidth > widthSingleImage * 1.5) {
    //   imageWidth = widthSingleImage * 1.5;
    //   imageHeight = imageWidth / imageInfo.aspectRatio;
    // }

    // if (imageHeight > heightSingleImage * 1.5) {
    //   imageHeight = heightSingleImage * 1.5;
    //   imageWidth = imageHeight * imageInfo.aspectRatio;
    // }

    return _buildImageItem(_attachments[0], imageWidth, imageHeight);
  }

  // Hiển thị 2 ảnh cạnh nhau
  Widget _buildTwoImages() {
    // Kích thước các ô mặc định
    double cellWidth = 120;
    double cellHeight = 150;

    // Nếu có thông tin về kích thước ảnh và có 2 ảnh
    if (_imageDimensions.length == 2) {
      final img1 = _imageDimensions[0];
      final img2 = _imageDimensions[1];

      // Nếu cả 2 ảnh đều ngang hoặc đều dọc thì giữ nguyên bố cục
      if (img1.isLandscape == img2.isLandscape) {
        // Điều chỉnh chiều cao nếu cả hai ảnh có tỉ lệ tương tự
        if (img1.isLandscape) {
          // Tính chiều cao trung bình cho ảnh ngang
          final avgAspectRatio = (img1.aspectRatio + img2.aspectRatio) / 2;
          cellHeight = cellWidth / avgAspectRatio;
        } else {
          // Giữ nguyên chiều cao cho ảnh dọc
          cellHeight = 150;
        }
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildImageItem(
          _attachments[0],
          cellWidth,
          cellHeight,
          customBorderRadius: const BorderRadius.only(
            topLeft: defaultBorderBubble,
            bottomLeft: defaultBorderBubble,
          ),
        ),
        const SizedBox(width: 2),
        _buildImageItem(
          _attachments[1],
          cellWidth,
          cellHeight,
          customBorderRadius: const BorderRadius.only(
            topRight: defaultBorderBubble,
            bottomRight: defaultBorderBubble,
          ),
        ),
      ],
    );
  }

  // Hiển thị 3 ảnh (1 ảnh lớn + 2 ảnh nhỏ)
  Widget _buildThreeImages() {
    double mainImgWidth = 160;
    double mainImgHeight = 160;
    double smallImgWidth = 80;
    double smallImgHeight = 79;

    // Nếu có thông tin kích thước của ít nhất ảnh đầu tiên
    if (_imageDimensions.isNotEmpty) {
      final mainImg = _imageDimensions[0];

      // Điều chỉnh chiều cao ảnh chính nếu cần
      if (mainImg.isLandscape) {
        mainImgHeight = mainImgWidth / mainImg.aspectRatio;
        // Đảm bảo không quá thấp
        if (mainImgHeight < 120) {
          mainImgHeight = 120;
        }
      } else {
        // Đối với ảnh dọc, giữ nguyên chiều cao và điều chỉnh chiều rộng
        mainImgWidth = mainImgHeight * mainImg.aspectRatio;
        // Đảm bảo không quá hẹp
        if (mainImgWidth < 120) {
          mainImgWidth = 120;
        }
      }

      // Điều chỉnh chiều cao các ảnh nhỏ để tổng bằng ảnh lớn
      smallImgHeight = (mainImgHeight - 2) / 2;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildImageItem(
          _attachments[0],
          mainImgWidth,
          mainImgHeight,
          customBorderRadius: const BorderRadius.only(
            topLeft: defaultBorderBubble,
            bottomLeft: defaultBorderBubble,
          ),
        ),
        const SizedBox(width: 2),
        Column(
          children: [
            _buildImageItem(
              _attachments[1],
              smallImgWidth,
              smallImgHeight,
              customBorderRadius: const BorderRadius.only(
                topRight: defaultBorderBubble,
              ),
            ),
            const SizedBox(height: 2),
            _buildImageItem(
              _attachments[2],
              smallImgWidth,
              smallImgHeight,
              customBorderRadius: const BorderRadius.only(
                bottomRight: defaultBorderBubble,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Hiển thị 4 ảnh (lưới 2x2)
  Widget _buildFourImages() {
    double cellWidth = 99;
    double cellHeight = 99;

    // Nếu có thông tin về kích thước của ảnh và có đủ 4 ảnh
    if (_imageDimensions.length == 4) {
      // Kiểm tra xem có cả ảnh ngang và dọc không
      bool hasLandscape = _imageDimensions.any((dim) => dim.isLandscape);
      bool hasPortrait = _imageDimensions.any((dim) => !dim.isLandscape);

      // Nếu có cả ảnh ngang và dọc, giữ nguyên lưới vuông
      if (hasLandscape && hasPortrait) {
        // Giữ nguyên kích thước
      }
      // Nếu tất cả đều ngang, điều chỉnh chiều cao
      else if (hasLandscape && !hasPortrait) {
        // Tính tỉ lệ trung bình
        double avgAspect =
            _imageDimensions.map((d) => d.aspectRatio).reduce((a, b) => a + b) /
            4;
        cellHeight = cellWidth / avgAspect;
        // Đảm bảo không quá thấp
        if (cellHeight < 70) cellHeight = 70;
      }
      // Nếu tất cả đều dọc, điều chỉnh chiều rộng
      else if (!hasLandscape && hasPortrait) {
        // Tính tỉ lệ trung bình
        double avgAspect =
            _imageDimensions.map((d) => d.aspectRatio).reduce((a, b) => a + b) /
            4;
        cellWidth = cellHeight * avgAspect;
        // Đảm bảo không quá hẹp
        if (cellWidth < 70) cellWidth = 70;
      }
    }

    return SizedBox(
      width: cellWidth * 2 + 2,
      height: cellHeight * 2 + 2,
      child: Column(
        children: [
          Row(
            children: [
              _buildImageItem(
                _attachments[0],
                cellWidth,
                cellHeight,
                customBorderRadius: const BorderRadius.only(
                  topLeft: defaultBorderBubble,
                ),
              ),
              const SizedBox(width: 2),
              _buildImageItem(
                _attachments[1],
                cellWidth,
                cellHeight,
                customBorderRadius: const BorderRadius.only(
                  topRight: defaultBorderBubble,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _buildImageItem(
                _attachments[2],
                cellWidth,
                cellHeight,
                customBorderRadius: const BorderRadius.only(
                  bottomLeft: defaultBorderBubble,
                ),
              ),
              const SizedBox(width: 2),
              _buildImageItem(
                _attachments[3],
                cellWidth,
                cellHeight,
                customBorderRadius: const BorderRadius.only(
                  bottomRight: defaultBorderBubble,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Hiển thị nhiều ảnh (>4) - dạng lưới với nút xem thêm
  Widget _buildMultipleImages() {
    double cellWidth = 99;
    double cellHeight = 99;

    return SizedBox(
      width: cellWidth * 2 + 2,
      height: cellHeight * 2 + 2,
      child: Column(
        children: [
          Row(
            children: [
              _buildImageItem(
                _attachments[0],
                cellWidth,
                cellHeight,
                customBorderRadius: const BorderRadius.only(
                  topLeft: defaultBorderBubble,
                ),
              ),
              const SizedBox(width: 2),
              _buildImageItem(
                _attachments[1],
                cellWidth,
                cellHeight,
                customBorderRadius: const BorderRadius.only(
                  topRight: defaultBorderBubble,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _buildImageItem(
                _attachments[2],
                cellWidth,
                cellHeight,
                customBorderRadius: const BorderRadius.only(
                  bottomLeft: defaultBorderBubble,
                ),
              ),
              const SizedBox(width: 2),
              _buildLastItem(),
            ],
          ),
        ],
      ),
    );
  }

  // Xây dựng item cuối cùng (có thể chứa overlay nếu có nhiều hơn 4 ảnh)
  Widget _buildLastItem() {
    double cellWidth = 99;
    double cellHeight = 99;

    Widget image = _buildImageItem(
      _attachments[3],
      cellWidth,
      cellHeight,
      customBorderRadius: const BorderRadius.only(
        bottomRight: defaultBorderBubble,
      ),
    );

    if (_attachments.length > 4) {
      return GestureDetector(
        onTap: () {
          print('Tapped on more images');
          // Mở ảnh trong chế độ xem đầy đủ hoặc hiển thị danh sách ảnh
        },
        child: Stack(
          children: [
            image,
            Container(
              width: cellWidth,
              height: cellHeight,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomRight: defaultBorderBubble,
                ),
              ),
              child: Center(
                child: Text(
                  '+${_attachments.length - 4}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return image;
  }
}

// Lớp để lưu trữ thông tin về kích thước ảnh
class ImageDimension {
  final String imageUrl;
  final double aspectRatio; // width / height
  final bool isLandscape; // true nếu width > height
  final double? width;
  final double? height;
  ImageDimension(
    this.imageUrl,
    this.aspectRatio,
    this.isLandscape, {
    this.width,
    this.height,
  });
}
