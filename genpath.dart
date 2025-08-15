import 'dart:io';

/*
file này dùng để generate các đường dẫn đến tài nguyên trong thư mục assets. VD: thay vì dùng 'assets/svg/icon_close.svg' thì gọi SvgPath.icon_close (class SvgPath đã được generate)
Chạy lệnh: dart run genpath.dart
*/
void main() {
  // Path to assets directory
  final assetsDir = Directory('assets');

  // Generate SVG paths
  final svgDir = Directory('${assetsDir.path}/svg');
  if (svgDir.existsSync()) {
    final svgPaths = svgDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.svg'))
        .map((file) {
      final filename = file.path.split('/').last;
      final varName = filename
          .replaceAll('.svg', '')
          .replaceAll('-', '_')
          .replaceAll(' ', '_')
          .toLowerCase();
      return "  static const String $varName = '${file.path}';";
    }).join('\n');

    final svgClass = '''
class SvgPath {
$svgPaths
}
''';

    File('lib/assets_path/svg.dart').writeAsStringSync(svgClass); //svg
  }

  print('SVG paths generated successfully');
  // Generate PNG paths
  final pngDir = Directory('${assetsDir.path}/image');
  if (pngDir.existsSync()) {
    final pngPaths = pngDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'))
        .map((file) {
      final filename = file.path.split('/').last;
      final varName = filename
          .replaceAll('.png', '')
          .replaceAll('-', '_')
          .replaceAll(' ', '_')
          .toLowerCase();
      return "  static const String $varName = '${file.path}';";
    }).join('\n');

    final pngClass = '''
class PngPath {
$pngPaths
}
''';

    File('lib/assets_path/image.dart').writeAsStringSync(pngClass);
    print('PNG paths generated successfully');
  }
  //generate json
  final jsonDir = Directory('${assetsDir.path}/json');
  if (jsonDir.existsSync()) {
    final jsonPaths = jsonDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .map((file) {
      final filename = file.path.split('/').last;
      final varName = filename
          .replaceAll('.json', '')
          .replaceAll('-', '_')
          .replaceAll(' ', '_')
          .toLowerCase();
      return "  static const String $varName = '${file.path}';";
    }).join('\n');

    final jsonClass = '''
class JsonPath {
$jsonPaths
}
''';

    File('lib/assets_path/json.dart').writeAsStringSync(jsonClass);
    print('JSON paths generated successfully');
  }
  //generate audio
  final audioDir = Directory('${assetsDir.path}/audio');
  if (audioDir.existsSync()) {
    final audioPaths = audioDir
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'\.(mp3|aac)').hasMatch(file.path))
        .map((file) {
      final filename = file.path.split('/').last;
      final varName = filename
          .replaceAll(RegExp(r'.mp3|.aac'), '')
          // .replaceAll('.mp3', '')
          .replaceAll('-', '_')
          .replaceAll(' ', '_')
          .toLowerCase();
      return "  static const String $varName = '${file.path}';";
    }).join('\n');

    final audioClass = '''
class AudioPath {
$audioPaths
}
''';

    File('lib/assets_path/audio.dart').writeAsStringSync(audioClass);
    print('Audio paths generated successfully');
  }
}
