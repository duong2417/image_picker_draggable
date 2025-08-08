import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:user_interface/user_interface.dart';

class PhotoGridView extends StatefulWidget {
  final List<Uint8List> thumbnails;
  final List<File> files;
  final void Function(List<File> selectedFiles) onAssetSelected;
  final VoidCallback onLoadMore;
  final VoidCallback? onScrollDownAtTop;
  final VoidCallback? onCameraTap;

  const PhotoGridView({
    super.key,
    required this.thumbnails,
    required this.files,
    required this.onAssetSelected,
    required this.onLoadMore,
    this.onScrollDownAtTop,
    this.onCameraTap,
  });

  @override
  State<PhotoGridView> createState() => _PhotoGridViewState();
}

class _PhotoGridViewState extends State<PhotoGridView> {
  final ScrollController _controller = ScrollController();
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.position.pixels <= 0 &&
        _controller.position.userScrollDirection == ScrollDirection.forward) {
      widget.onScrollDownAtTop?.call();
    }

    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 500) {
      widget.onLoadMore();
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });

    final selectedFiles = _selectedIndices
        .where((i) => i > 0 && i - 1 < widget.files.length)
        .map((i) => widget.files[i - 1]) // vì index 0 là máy ảnh
        .toList();

    widget.onAssetSelected(selectedFiles);
  }

  int _getSelectionOrder(int index) {
    final sorted = _selectedIndices.toList()..sort();
    return sorted.indexOf(index) + 1;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is OverscrollNotification &&
            notification.overscroll <= 0 &&
            _controller.offset < 0) {
          debugPrint('bẹp bẹp bẹp');
          widget.onScrollDownAtTop?.call();
          return true;
        }
        return false;
      },
      child: GridView.builder(
        padding: EdgeInsets.zero,
        controller: _controller,
        itemCount: widget.thumbnails.length + 1, // +1 cho icon camera
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: () {
                widget.onCameraTap?.call();
              },
              child: Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.photo_camera,
                  size: 24,
                  color: Colors.black54,
                ),
              ),
            );
          }

          final thumbnail = widget.thumbnails[index - 1];
          final isSelected = _selectedIndices.contains(index);
          final selectionOrder = isSelected ? _getSelectionOrder(index) : null;

          return GestureDetector(
            onTap: () => _toggleSelection(index),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(thumbnail, fit: BoxFit.cover),
                // Hiệu ứng chọn ảnh
                AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: isSelected ? 0.95 : 1.0,
                  child: Container(),
                ),

                if (selectionOrder != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.appTheme,
                      child: Text(
                        "$selectionOrder",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
