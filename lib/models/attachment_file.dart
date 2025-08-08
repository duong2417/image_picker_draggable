import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:image_picker_with_draggable/utils/extensions.dart';

class AttachmentFile {
  AttachmentFile({required this.size, this.path, String? name, this.bytes})
    : assert(
        path != null || bytes != null,
        'Either path or bytes should be != null',
      ),
      assert(
        name == null || name.isEmpty || name.contains('.'),
        'Invalid file name, should also contain file extension',
      ),
      _name = name;

  /// The absolute path for a cached copy of this file. It can be used to
  /// create a file instance with a descriptor for the given path.
  /// ```
  /// final File myFile = File(platformFile.path);
  /// ```
  final String? path;

  final String? _name;

  /// File name including its extension.
  String? get name {
    if (_name case final name? when name.isNotEmpty) return name;
    return path?.split('/').last;
  }

  /// Byte data for this file. Particularly useful if you want to manipulate
  /// its data or easily upload to somewhere else.
  final Uint8List? bytes;

  /// The file size in bytes.
  final int? size;

  /// File extension for this file.
  String? get extension => name?.split('.').last;

  /// The mime type of this file.
  MediaType? get mediaType => name?.mediaType;

  AttachmentFile copyWith({
    String? path,
    String? name,
    Uint8List? bytes,
    int? size,
  }) {
    return AttachmentFile(
      path: path ?? this.path,
      name: name ?? this.name,
      bytes: bytes ?? this.bytes,
      size: size ?? this.size,
    );
  }
}
