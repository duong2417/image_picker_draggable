import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker_with_draggable/edit_image/image_full_screen.dart';
import 'package:image_picker_with_draggable/edit_image/image_tile.dart';
import 'package:image_picker_with_draggable/thumbnail/photo_gallery_tile.dart';
import 'package:image_picker_with_draggable/common/empty_widget.dart';
import 'package:image_picker_with_draggable/common/loading_widget.dart';
import 'package:image_picker_with_draggable/common/paged_value_scrollview.dart';
import 'package:image_picker_with_draggable/utils/const.dart';
import 'package:image_picker_with_draggable/models/error_model.dart';
import 'package:image_picker_with_draggable/utils/helper.dart';
import 'package:photo_manager/photo_manager.dart';

import '../handler/photo_gallery_controller.dart';

class GalleryPicker extends StatefulWidget {
  const GalleryPicker({
    super.key,
    this.limit = 50,
    this.scrollController,
    this.onScrollDownAtTop,
    required this.onTap,
    required this.selectedMediaItems,
  });

  /// Maximum number of media items that can be selected.
  final int limit;

  final ScrollController? scrollController;

  final VoidCallback? onScrollDownAtTop;

  final Function(AssetEntity media) onTap;

  final Iterable<String> selectedMediaItems;

  @override
  State<GalleryPicker> createState() => _GalleryPickerState();
}

class _GalleryPickerState extends State<GalleryPicker> {
  Future<PermissionState>? requestPermission;
  late PhotoGalleryController _controller;
  late ScrollController _scrollController;
  @override
  void initState() {
    super.initState();
    requestPermission = runInPermissionRequestLock(
      PhotoManager.requestPermissionExtend,
    );
    _controller = PhotoGalleryController();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(GalleryPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.limit != oldWidget.limit) {
      _controller.dispose();
      _controller = PhotoGalleryController(limit: widget.limit);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 0 &&
        _scrollController.position.userScrollDirection ==
            ScrollDirection.forward) {
      widget.onScrollDownAtTop?.call();
    }
    // if (_scrollController.position.pixels >=
    //     _scrollController.position.maxScrollExtent - 500) {
    //   widget.onLoadMore();
    // }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // return Container(color: Colors.yellow);//ok
    return FutureBuilder(
      future: requestPermission,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Empty();
        // Available on both Android and iOS.
        final isAuthorized = snapshot.data == PermissionState.authorized;
        // Only available on iOS.
        final isLimited = snapshot.data == PermissionState.limited;

        final isPermissionGranted = isAuthorized || isLimited;

        return Builder(
          builder: (context) {
            if (!isPermissionGranted) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 240, color: disabledColor),
                  Text(
                    'Enable photo and video access message',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: PhotoManager.openSetting,
                    child: Text('Allow gallery access message'),
                  ),
                ],
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is OverscrollNotification &&
                    notification.overscroll <= 0 &&
                    _scrollController.offset < 0) {
                  debugPrint('bẹp bẹp bẹp');
                  widget.onScrollDownAtTop?.call();
                  return true;
                }
                return false;
              },
              child: PagedValueGridView<int, AssetEntity>(
                padding: const EdgeInsets.all(
                  0,
                ), //để sheet ko bị cách mép trên 1 đoạn
                scrollController: _scrollController,
                controller: _controller,
                itemBuilder: (context, mediaList, index) {
                  final media = mediaList[index];
                  return ImageTile(
                    // selected: widget.selectedMediaItems.contains(media.id),
                    asset: media,
                    selectedAssets: widget.selectedMediaItems,
                    onPickImage: (assetEntity) {
                      //tap ô chọn
                      print(
                        'onPickImage trong gallery_picker: ${assetEntity.id}',
                      );
                      widget.onTap(assetEntity);
                    },
                    onTap: (assetEntity) {
                      //tap image xem full
                      print('onTap trong gallery_picker: ${assetEntity.id}');
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => ImageFullScreen(
                                isHD: true,
                                onEditDone: (String path) {
                                  print('onEditDone: $path');
                                },
                                files: mediaList,
                                currentIndex: index,
                                selectedAssets:
                                    widget.selectedMediaItems.toList(),
                              ),
                        ),
                      );
                      // widget.onTap(assetEntity);
                    },
                    editedImagePath: null,
                    index: index,
                    caption: 'cap null',
                  );
                  return PhotoGalleryTile(
                    selected: widget.selectedMediaItems.contains(media.id),
                    media: media,
                    onTap: () {
                      widget.onTap(media);
                      debugPrint('Tapped on media: ${media.id}');
                    },
                  );
                },
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                emptyBuilder: (BuildContext context) {
                  return Center(
                    child: Text(
                      'No media found',
                      style: TextStyle(color: disabledColor),
                    ),
                  );
                },
                loadMoreErrorBuilder: (BuildContext context, ErrorModel error) {
                  return ErrorWidget(error.toString());
                },
                loadMoreIndicatorBuilder: (BuildContext context) {
                  return Loading();
                },
                loadingBuilder: (BuildContext context) {
                  return Loading();
                },
                errorBuilder: (BuildContext context, ErrorModel error) {
                  return ErrorWidget(error.toString());
                },
              ),
            );
          },
        );
      },
    );
  }
}
