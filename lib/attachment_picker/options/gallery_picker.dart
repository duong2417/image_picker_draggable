import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/attachment_picker/options/stream_attachment_picker.dart';
import 'package:image_picker_with_draggable/attachment_picker/photo_gallery/stream_photo_gallery_tile.dart';
import 'package:image_picker_with_draggable/common/empty_widget.dart';
import 'package:image_picker_with_draggable/common/paged_value_scrollview.dart';
import 'package:image_picker_with_draggable/const.dart';
import 'package:image_picker_with_draggable/models/error_model.dart';
import 'package:image_picker_with_draggable/utils/helper.dart';
import 'package:photo_manager/photo_manager.dart';

import 'photo_gallery_controller.dart';

class GalleryPicker extends StatefulWidget {
  const GalleryPicker({
    super.key,
    this.limit = 50,
    required this.scrollController,
  });

  /// Maximum number of media items that can be selected.
  final int limit;

  final ScrollController scrollController;

  @override
  State<GalleryPicker> createState() => _GalleryPickerState();
}

class _GalleryPickerState extends State<GalleryPicker> {
  Future<PermissionState>? requestPermission;
  late PhotoGalleryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PhotoGalleryController();
    requestPermission = runInPermissionRequestLock(
      PhotoManager.requestPermissionExtend,
    );
  }

  @override
  void didUpdateWidget(GalleryPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.limit != oldWidget.limit) {
      _controller.dispose();
      _controller = PhotoGalleryController(limit: widget.limit);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: requestPermission,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Empty();
        // Available on both Android and iOS.
        final isAuthorized = snapshot.data == PermissionState.authorized;
        // Only available on iOS.
        final isLimited = snapshot.data == PermissionState.limited;

        final isPermissionGranted = isAuthorized || isLimited;

        return OptionDrawer(
          actions: [
            if (isLimited)
              IconButton(
                color: Colors.green,
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: () async {
                  await PhotoManager.presentLimited();
                  _controller.doInitialLoad();
                },
              ),
          ],
          child: Builder(
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
              return PagedValueGridView<int, AssetEntity>(
                scrollController: widget.scrollController,
                controller: _controller,
                itemBuilder: (context, mediaList, index) {
                  final media = mediaList[index];
                  // final onTap = onMediaTap;
                  // final onLongPress = onMediaLongPress;

                  final streamPhotoGalleryTile = StreamPhotoGalleryTile(
                    media: media,
                    // onTap: onTap == null ? null : () => onTap(media),
                    // onLongPress:
                    //     onLongPress == null ? null : () => onLongPress(media),
                    // thumbnailSize: thumbnailSize,
                    // thumbnailFormat: thumbnailFormat,
                    // thumbnailQuality: thumbnailQuality,
                    // thumbnailScale: thumbnailScale,
                  );
                  return streamPhotoGalleryTile;
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
                  return Center(child: Text(error.toString()));
                },
                loadMoreIndicatorBuilder: (BuildContext context) {
                  return const Center(child: CircularProgressIndicator());
                },
                loadingBuilder: (BuildContext context) {
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (BuildContext context, ErrorModel error) {
                  return Center(child: Text(error.toString()));
                },
              );
            },
          ),
        );
      },
    );
  }
}
