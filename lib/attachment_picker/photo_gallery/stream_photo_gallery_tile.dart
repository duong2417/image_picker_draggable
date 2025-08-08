import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// Widget that displays a photo or video item from the gallery.
class StreamPhotoGalleryTile extends StatelessWidget {
  /// Creates a new instance of [StreamPhotoGalleryTile].
  const StreamPhotoGalleryTile({
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
  StreamPhotoGalleryTile copyWith({
    Key? key,
    AssetEntity? media,
    bool? selected,
    GestureTapCallback? onTap,
    GestureLongPressCallback? onLongPress,
    ThumbnailSize? thumbnailSize,
    ThumbnailFormat? thumbnailFormat,
    int? thumbnailQuality,
    double? thumbnailScale,
  }) => StreamPhotoGalleryTile(
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
          // child: Text('placeHolder'),
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
                color: Colors.pink,
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

/// {@template mediaThumbnailProvider}
/// Builds a thumbnail using [ImageProvider].
/// {@endtemplate}
class MediaThumbnailProvider extends ImageProvider<MediaThumbnailProvider> {
  /// {@macro mediaThumbnailProvider}
  const MediaThumbnailProvider({
    required this.media,
    // TODO: Are these sizes optimal? Consider web/desktop
    this.size = const ThumbnailSize(400, 400),
    this.format = ThumbnailFormat.jpeg,
    this.quality = 100,
    this.scale = 1,
  });

  /// Media to load
  final AssetEntity media;

  /// The thumbnail size.
  final ThumbnailSize size;

  /// {@macro photo_manager.ThumbnailFormat}
  final ThumbnailFormat format;

  /// The quality value for the thumbnail.
  ///
  /// Valid from 1 to 100.
  /// Defaults to 100.
  final int quality;

  /// Scale of the image.
  final double scale;

  @override
  Future<MediaThumbnailProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<MediaThumbnailProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    MediaThumbnailProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>(
          'Thumbnail provider: $this \n Thumbnail key: $key',
          this,
          style: DiagnosticsTreeStyle.errorProperty,
        );
      },
    );
  }

  Future<ui.Codec> _loadAsync(
    MediaThumbnailProvider key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this, '$key is not $this');
    final bytes = await media.thumbnailDataWithSize(
      size,
      format: format,
      quality: quality,
    );
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes!);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other is MediaThumbnailProvider) {
      return media == other.media &&
          size == other.size &&
          format == other.format &&
          quality == other.quality &&
          scale == other.scale;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(media, size, format, quality, scale);

  @override
  String toString() =>
      '$runtimeType('
      'media: $media, '
      'size: $size, '
      'format: $format, '
      'quality: $quality, '
      'scale: $scale'
      ')';
}
