import 'dart:async';

import 'package:flutter/services.dart';
import 'package:synchronized/synchronized.dart';

void showKeyboard() {
  SystemChannels.textInput.invokeMethod('TextInput.show');
}

void hideKeyboard() {
  SystemChannels.textInput.invokeMethod('TextInput.hide');
}

/*
Đảm bảo tính tuần tự (Serialization): Chỉ cho phép một tác vụ bất đồng bộ chạy cùng một lúc khi lock được giữ
Tránh race conditions: Ngăn chặn nhiều threads/isolates cùng truy cập vào tài nguyên được bảo vệ
Quản lý quyền truy cập: Đặc biệt hữu ích cho việc request permissions từ hệ thống

Scenario 1: User tương tác nhanh
 - user tap liên tiếp nhiều lần vào nút pickPhoto
- user tap nút này xong ngay lập tức tap nút khác
Scenario 2: Lifecycle events:
App resume từ background trong khi permission dialog đang show
→ Có thể trigger thêm permission request

  ko dùng thì:
  - nhiều dialog request permission sẽ hiện lên
*/
Future<T> runInPermissionRequestLock<T>(
  FutureOr<T> Function() computation, {
  Duration? timeout,
}) {
  return _permissionRequestLock.synchronized(computation, timeout: timeout);
}

final _permissionRequestLock = Lock();
