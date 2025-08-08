import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

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
