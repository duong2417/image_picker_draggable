import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:image_picker_with_draggable/common/show/show_error.dart';

p(String s, {String? t, bool show = false}) {
  log('$t;;;$s');
  if (show == true) {
    showErrorDialog('$t');
  }
}

final luongStream = StreamController<String>.broadcast();
String _luong = '';
bool _reset = false;
resetLuong() {
  _luong = '';
  luongStream.add(_luong);
}

luon(
  String s, {
  bool? su,
  bool reset = false,
  bool resetLien = false,
  bool print = false,
}) async {
  if (!kDebugMode) {
    return;
  }
  if (print == true) {
    p('luon: $s');
  }
  if (resetLien == true || _luong.length > 1000) {
    _luong = '';
  }
  if (_reset == true) {
    _luong = '';
    _reset = false;
    await Future.delayed(
      const Duration(seconds: 5),
    ); //dừng lại 3s để đọc rồi mới xoá
  }
  if (reset == true) {
    _reset =
        true; //reset ở lần sau chứ ko phải ngay lần này. tưc là ở lần sau, sẽ reset trc khi add data mới
  }
  if (su == true) {
    _luong += '✅'; // Green check emoji
  } else if (su == false) {
    _luong += '❌'; // Red X emoji
    return;
  }
  _luong += '$s\n\n';
  luongStream.add(_luong);
}
