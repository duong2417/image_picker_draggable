import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/image_picker_with_draggable.dart';
import 'package:photo_manager/photo_manager.dart';

import 'const.dart';
import 'utils/helper.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  late final ValueNotifier<bool> showActionUtilTapOutside;
  bool showActions = false;

  // Photo loading variables
  final ValueNotifier<List<Uint8List>> thumbnailsNotifier = ValueNotifier([]);
  final ValueNotifier<List<File>> filesNotifier = ValueNotifier([]);
  final List<AssetEntity> _assetEntities = [];

  static const int _thumbnailSize = 200;
  static const int _limit = 40;

  bool _isLoading = false;
  bool _hasMore = true;
  AssetPathEntity? _album;

  // Additional variables needed for the new implementation
  final FocusNode _focusNode = FocusNode();

  void _setSx(double value) {
    // Handle sx value
  }

  void _setSy(double value) {
    // Handle sy value
  }
  @override
  void initState() {
    super.initState();
    showActionUtilTapOutside = ValueNotifier<bool>(false);
    WidgetsBinding.instance.addObserver(this);
    // Load initial photos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      load(isInitial: true);
    });
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

  Future<void> load({bool isInitial = false}) async {
    if (_isLoading || (!_hasMore && !isInitial)) return;
    _isLoading = true;

    if (_album == null || isInitial) {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        await PhotoManager.openSetting();
        _isLoading = false;
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      if (albums.isEmpty) {
        _isLoading = false;
        return;
      }

      _album = albums.first;

      if (isInitial) {
        _assetEntities.clear();
        thumbnailsNotifier.value = [];
        filesNotifier.value = [];
        _hasMore = true;
      }
    }

    final startIndex = _assetEntities.length;

    final nextAssets = await _album!.getAssetListRange(
      start: startIndex,
      end: startIndex + _limit,
    );

    if (nextAssets.isEmpty) {
      _hasMore = false;
      _isLoading = false;
      return;
    }

    _assetEntities.addAll(nextAssets);

    // Lấy thumbnail
    final newThumbs = await Future.wait(
      nextAssets.map(
        (asset) => asset.thumbnailDataWithSize(
          const ThumbnailSize(_thumbnailSize, _thumbnailSize),
        ),
      ),
    );

    // Lấy file thật
    final newFiles = await Future.wait(
      nextAssets.map((asset) async => await asset.file),
    );

    thumbnailsNotifier.value = [
      ...thumbnailsNotifier.value,
      ...newThumbs.whereType<Uint8List>(),
    ];

    filesNotifier.value = [
      ...filesNotifier.value,
      ...newFiles.whereType<File>(),
    ];

    _isLoading = false;
  }

  AssetEntity getAssetAt(int index) => _assetEntities[index];

  void _sendImageAndMessage(List<File> files) {
    // Implement your image sending logic here
    for (File file in files) {
      print('Sending image: ${file.path}');
    }
  }

  @override
  dispose() {
    super.dispose();
    showActionUtilTapOutside.dispose();
    thumbnailsNotifier.dispose();
    filesNotifier.dispose();
    _focusNode.dispose();
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
                      Expanded(child: TextField(focusNode: _focusNode)),
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
                builder: (context, showActionUtilTapOutside1, child) {
                  if (!showActionUtilTapOutside1) {
                    return const SizedBox.shrink();
                  }
                  return ImagePickerBottomsheet(
                    key: ValueKey(heightKeyboard), //cp
                    height: maxHeightKeyboard - heightKeyboard,
                    hideBottomSheet: () {
                      showActionUtilTapOutside.value = false;
                      _focusNode.requestFocus();
                      debugPrint('Bẹp tiếp nè');
                    },
                  );
                  //   return Positioned(
                  //     bottom: 0,
                  //     left: 0,
                  //     right: 0,
                  //     child: ValueListenableBuilder<List<Uint8List>>(
                  //       valueListenable: thumbnailsNotifier,
                  //       builder: (context, thumbnails, _) {
                  //         if (thumbnails.isEmpty) {
                  //           return const SizedBox.shrink();
                  //         }

                  //         return ValueListenableBuilder<List<File>>(
                  //           valueListenable: filesNotifier,
                  //           builder: (context, files, _) {
                  //             return ImagePickerBottomsheet(
                  //                 key: ValueKey(heightKeyboard),
                  //                 height:
                  //                     maxHeightKeyboard - heightKeyboard,
                  //                 thumbnails: thumbnails,
                  //                 files:
                  //                     files,
                  //                 onLoadMore: () {
                  //                   load(isInitial: false);
                  //                 },
                  //                 sx: _setSx,
                  //                 sy: _setSy,
                  // hideBottomSheet: () {
                  //   showActionUtilTapOutside.value = false;
                  //   _focusNode.requestFocus();
                  //   debugPrint('Bẹp tiếp nè');
                  // },
                  //                 callbackFile: (e) {
                  //                   _sendImageAndMessage(e);
                  //                   if (showActionUtilTapOutside.value ==
                  //                       true) {
                  //                     Future.delayed(
                  //                        const Duration(microseconds: 500), () {
                  //                       showActionUtilTapOutside.value =
                  //                           false;
                  //                       _focusNode.requestFocus();
                  //                     });
                  //                   }
                  //                 });
                  //           },
                  //         );
                  //       },
                  //     ),
                  //   );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
