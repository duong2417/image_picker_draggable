import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/common/wrap_screen.dart';
import 'package:image_picker_with_draggable/handler/attachment_picker_controller.dart';
import 'package:image_picker_with_draggable/widgets/image_picker_bottom_sheet.dart';
import 'package:image_picker_with_draggable/models/message.dart';
import 'package:image_picker_with_draggable/widgets/message_list_view.dart';
import 'utils/const.dart';
import 'models/attachment.dart';
import 'utils/helper.dart';
import 'models/upload_state.dart';
import 'services/upload_simulator.dart';

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
  // final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AttachmentPickerController attachmentCtrl;

  // Messages list
  final ValueNotifier<List<Message>> messagesNotifier = ValueNotifier([]);
  List<Attachment> get attachments => attachmentCtrl.value.attachments;

  // Track upload subscriptions by message id
  final Map<String, List<StreamSubscription<UploadState>>> _uploadSubs = {};

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
    // _focusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    attachmentCtrl.dispose();
    messagesNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    // Cancel any running upload simulations
    for (final subs in _uploadSubs.values) {
      for (final s in subs) {
        s.cancel();
      }
    }
    _uploadSubs.clear();
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

    // Start simulated uploads for this message
    if (message.attachments.isNotEmpty) {
      _simulateUploadsForMessage(message);
    }

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

  void _simulateUploadsForMessage(Message message) {
    // Ensure list for this message
    _uploadSubs[message.id] = _uploadSubs[message.id] ?? [];
    for (final att in message.attachments) {
      _startUploadForAttachment(message, att);
    }
  }

  void _startUploadForAttachment(Message message, Attachment attachment) {
    final stream = UploadSimulator.instance.uploadAttachment(attachment);
    final sub = stream.listen((state) {
      _updateAttachmentState(message.id, attachment.id, state);
    });
    _uploadSubs[message.id]!.add(sub);
  }

  void _updateAttachmentState(
    String messageId,
    String attachmentId,
    UploadState state,
  ) {
    final list = List<Message>.from(messagesNotifier.value);
    final mIndex = list.indexWhere((m) => m.id == messageId);
    if (mIndex < 0) return;
    final m = list[mIndex];

    final newAttachments =
        m.attachments.map((a) {
          if (a.id == attachmentId) {
            return a.copyWith(uploadState: state);
          }
          return a;
        }).toList();

    list[mIndex] = m.copyWith(attachments: newAttachments);
    messagesNotifier.value = list;
  }

  void _retryUpload(Message message, Attachment attachment) {
    // Reset to preparing immediately for UI feedback
    _updateAttachmentState(
      message.id,
      attachment.id,
      const UploadState.preparing(),
    );
    _startUploadForAttachment(message, attachment);
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
        body: ScreenWrap(
          width: 100,
          child: Stack(
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
                            onRetry: (m, a) => _retryUpload(m, a),
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
                                // focusNode: _focusNode,
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
                      showKeyboard();
                      // _focusNode.requestFocus();
                      debugPrint('Bẹp tiếp nè');
                    },
                
                    attachmentPickerController: attachmentCtrl,
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
