import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'media_thumbnail_provider.dart';

/// Widget that displays a photo or video item from the gallery.
class PhotoGalleryTile extends StatelessWidget {
  /// Creates a new instance of [PhotoGalleryTile].
  const PhotoGalleryTile({
    super.key,
    required this.media,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.thumbnailSize = const ThumbnailSize(400, 400),
    this.thumbnailFormat = ThumbnailFormat.jpeg,
    this.thumbnailQuality = 100,
    this.thumbnailScale = 1,
  });

  /// The media item to display.
  final AssetEntity media;

  /// Whether the media item is selected.
  final bool selected;

  /// Called when the user taps this grid tile.
  final GestureTapCallback? onTap;

  /// Called when the user long-presses on this grid tile.
  final GestureLongPressCallback? onLongPress;

  /// The thumbnail size.
  final ThumbnailSize thumbnailSize;

  /// {@macro photo_manager.ThumbnailFormat}
  final ThumbnailFormat thumbnailFormat;

  /// The quality value for the thumbnail.
  ///
  /// Valid from 1 to 100.
  /// Defaults to 100.
  final int thumbnailQuality;

  /// Scale of the image.
  final double thumbnailScale;

  /// Creates a copy of this tile but with the given fields replaced with
  /// the new values.
  PhotoGalleryTile copyWith({
    Key? key,
    AssetEntity? media,
    bool? selected,
    GestureTapCallback? onTap,
    GestureLongPressCallback? onLongPress,
    ThumbnailSize? thumbnailSize,
    ThumbnailFormat? thumbnailFormat,
    int? thumbnailQuality,
    double? thumbnailScale,
  }) => PhotoGalleryTile(
    key: key ?? this.key,
    media: media ?? this.media,
    selected: selected ?? this.selected,
    onTap: onTap ?? this.onTap,
    onLongPress: onLongPress ?? this.onLongPress,
    thumbnailSize: thumbnailSize ?? this.thumbnailSize,
    thumbnailFormat: thumbnailFormat ?? this.thumbnailFormat,
    thumbnailQuality: thumbnailQuality ?? this.thumbnailQuality,
    thumbnailScale: thumbnailScale ?? this.thumbnailScale,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: FadeInImage(
            placeholder: const AssetImage('assets/placeholder.png'),
            fadeInDuration: const Duration(milliseconds: 300),
            fit: BoxFit.cover,
            image: MediaThumbnailProvider(
              media: media,
              size: thumbnailSize,
              format: thumbnailFormat,
              quality: thumbnailQuality,
              scale: thumbnailScale,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: selected ? 1.0 : 0.0,
              child: Container(
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.check, size: 24, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        if (media.type == AssetType.video) ...[
          Positioned(
            left: 8,
            bottom: 10,
            child: Icon(Icons.video_call, size: 24, color: Colors.yellow),
          ),
          Positioned(
            right: 4,
            bottom: 10,
            child: Text(
              media.videoDuration.format(),
              style: TextStyle(color: Colors.brown),
            ),
          ),
        ],
        // https://stackoverflow.com/a/59317162/10036882
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, onLongPress: onLongPress),
          ),
        ),
      ],
    );
  }
}

extension on Duration {
  String format() {
    final s = '$this'.split('.')[0].padLeft(8, '0');
    if (s.startsWith('00:')) {
      return s.replaceFirst('00:', '');
    }

    return s;
  }
}
