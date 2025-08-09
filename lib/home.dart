import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/handler/attachment_picker_controller.dart';
import 'package:image_picker_with_draggable/image_picker_bottom_sheet.dart';
import 'package:image_picker_with_draggable/models/message.dart';
import 'package:image_picker_with_draggable/widgets/message_list_view.dart';
import 'const.dart';
import 'models/attachment.dart';
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
  // Additional variables needed for the new implementation
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AttachmentPickerController attachmentCtrl;

  // Messages list
  final ValueNotifier<List<Message>> messagesNotifier = ValueNotifier([]);
  List<Attachment> get attachments => attachmentCtrl.value.attachments;
  @override
  void initState() {
    super.initState();
    showActionUtilTapOutside = ValueNotifier<bool>(false);
    attachmentCtrl = AttachmentPickerController();
    WidgetsBinding.instance.addObserver(this);
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
    thumbnailsNotifier.dispose();
    filesNotifier.dispose();
    _focusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    attachmentCtrl.dispose();
    messagesNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
  }

  void _sendMessage({String? text, List<Attachment>? attachments}) {
    if ((text == null || text.trim().isEmpty) &&
        (attachments == null || attachments.isEmpty)) {
      return; // Không gửi tin nhắn trống
    }

    final message = Message.create(
      text: text?.trim(),
      attachments: attachments,
      isFromUser: true,
    );

    // Thêm tin nhắn vào danh sách
    final currentMessages = List<Message>.from(messagesNotifier.value);
    currentMessages.add(message);
    messagesNotifier.value = currentMessages;

    // Clear text field
    _textController.clear();
    attachmentCtrl.clearAttachments();

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    debugPrint('Đã gửi tin nhắn: ${message.type.name}');
    if (message.attachments.isNotEmpty) {
      debugPrint('Số lượng attachments: ${message.attachments.length}');
    }
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
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Column(
              children: [
                // Message list
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: ValueListenableBuilder<List<Message>>(
                      valueListenable: messagesNotifier,
                      builder: (context, messages, child) {
                        return MessageListView(
                          messages: messages,
                          scrollController: _scrollController,
                        );
                      },
                    ),
                  ),
                ),
                // Input area
                Container(
                  color: Colors.green,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              decoration: const InputDecoration(
                                hintText: 'Nhập tin nhắn...',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onSubmitted: (text) {
                                _sendMessage(text: text);
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final text = _textController.text.trim();
                              if (text.isNotEmpty || attachments.isNotEmpty) {
                                _sendMessage(
                                  text: text.isEmpty ? null : text,
                                  attachments: attachments,
                                );
                                // Đóng bottom sheet
                                // showActionUtilTapOutside.value = false;
                                // _focusNode.requestFocus();

                                debugPrint(
                                  'Đã gửi ${attachments.length} tệp đính kèm',
                                );
                              }
                            },
                            icon: const Icon(Icons.send),
                          ),
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
                            icon: const Icon(Icons.more_vert),
                          ),
                        ],
                      ),
                      ValueListenableBuilder(
                        valueListenable: showActionUtilTapOutside,
                        builder: (context, showActionUtilTapOutside, child) {
                          if (!showActionUtilTapOutside) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            height:
                                maxHeightKeyboard -
                                heightKeyboard, //TODO ko an toàn: check số âm
                            color: Colors.amber,
                            child: const Center(
                              child: Text('This is a bottom bar'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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
                  height:
                      maxHeightKeyboard -
                      heightKeyboard, //TODO ko an toàn: check số âm
                  hideBottomSheet: () {
                    showActionUtilTapOutside.value = false;
                    _focusNode.requestFocus();
                    debugPrint('Bẹp tiếp nè');
                  },

                  attachmentPickerController: attachmentCtrl,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
