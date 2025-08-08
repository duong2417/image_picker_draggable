import 'dart:async';

import 'package:flutter/material.dart';

import 'const.dart';
import 'utils/helper.dart';
import 'image_picker_with_draggable.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  late final ValueNotifier<bool> showActionUtilTapOutside;
  bool showActions = false;
  @override
  void initState() {
    super.initState();
    showActionUtilTapOutside = ValueNotifier<bool>(false);
  }

  double _lastKeyboardHeight = 0;
  Timer? _debounceTimer;

  @override
  void didChangeMetrics() {
    // Lấy chiều cao hiện tại của bàn phím (nếu có)
    final currentHeight = WidgetsBinding.instance.window.viewInsets.bottom;

    // Nếu giá trị thay đổi, đặt lại timer
    if (_lastKeyboardHeight != currentHeight) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 200), () {
        // Sau khoảng thời gian debounce, nếu giá trị không thay đổi nữa thì keyboard đã hiện full, thì ko hiện actionCtn nữa
        if (currentHeight > 0.0) {
          showActionUtilTapOutside.value =
              false; //vì đối với android14, lúc đầu keyboard hiện hàng số, sau khi focus field thì hàng số bị ẩn làm keyboard thấp xuống và lộ ra actionCtn (do height actionCtn = maxHeightKeyboad - heightKeyboard realtime nên actionCtn bị ẩn thực chất là do h = 0 chứ ko phải ẩn thực sự)
          print("Keyboard is fully visible with height: $currentHeight");
        }
      });
      _lastKeyboardHeight = currentHeight;
    }
  }

  @override
  dispose() {
    super.dispose();
    showActionUtilTapOutside.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final heightKeyboard = MediaQuery.of(context).viewInsets.bottom;
    if (heightKeyboard > maxHeightKeyboard) {
      maxHeightKeyboard = heightKeyboard;
    }
    // print('heightKeyboard: $heightKeyboard');
    return GestureDetector(
      onTap: () {
        //này để tap outside thì unfocus textfield và đóng bottom sheet
        //vừa unfocus vừa xóa lun history,để khi đóng bottomsheet thì nó ko khôi phục last focus => textfield ko bị autofocus. lỗi này sẽ bị khi dùng FocusScope.of(context).unfocus()
        FocusManager.instance.primaryFocus?.unfocus();
        if (showActionUtilTapOutside.value) {
          showActionUtilTapOutside.value = false;
          showActions = false;
          hideKeyboard();
        }
      },
      child: Scaffold(
        body: Container(
          color: Colors.green,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(child: TextField()),
                      IconButton(
                        onPressed: () {
                          showActionUtilTapOutside.value = true;
                          showActions = !showActions;
                          if (showActions == true) {
                            hideKeyboard();
                          } else {
                            showKeyboard();
                          }
                        },
                        icon: Icon(Icons.more_vert),
                      ),
                    ],
                  ),
                  ValueListenableBuilder(
                    valueListenable: showActionUtilTapOutside,
                    builder: (context, showActionUtilTapOutside, child) {
                      if (!showActionUtilTapOutside) {
                        return SizedBox.shrink();
                      }
                      return Container(
                        height:
                            maxHeightKeyboard -
                            heightKeyboard, // keyboardController.heightKeyboard,
                        color: Colors.amber,
                        child: Center(child: Text('This is a bottom bar')),
                      );
                    },
                  ),
                ],
              ),

              ValueListenableBuilder(
                valueListenable: showActionUtilTapOutside,
                builder: (context, showActionUtilTapOutside, child) {
                  if (!showActionUtilTapOutside) {
                    return SizedBox.shrink();
                  }
                  return ImagePickerBottomsheet(
                    key: ValueKey(
                      heightKeyboard,
                    ), //đảm bảo luôn rebuild lại mỗi khi heightKeyboard thay đổi (cụ thể là khi keyboard dãn dần ra thì sheet thu dần lại và ngược lại, đảm bảo textfield luôn đứng yên)
                    height: maxHeightKeyboard - heightKeyboard,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
