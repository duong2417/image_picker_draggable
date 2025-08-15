import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages, implementation_imports
import 'package:chatting/src/data/repositories/internal_chat_repository_imp.dart';
// ignore: depend_on_referenced_packages, implementation_imports
import 'package:chatting/src/domain/repositories/internal_chat_repository.dart';
/*
xử lý file ngầm:
đang gửi file mà back ra ngoài màn hình, Thì app tiếp tục gửi file

Hiện tại đã gửi ngầm dc nhưng back ra vào lại chưa hiện lên giao diện

Mục đích: Dịch vụ upload chạy ngầm cho màn chat. Tiếp tục gửi file khi rời màn hình và khôi phục tiến trình/UI khi vào lại.
Kiến trúc:
Singleton UploadService.
Sử dụng InternalChatRepositoryImp để gửi ảnh/file.
Lưu tạm theo filePath:
_uploadProgress: ValueNotifier<double> theo dõi tiến trình.
_uploadTasks: Completer<ChatDetail> nhận kết quả gửi.
_tempDetails: ChatDetail tạm để hiển thị.
Persist trạng thái:
SharedPreferences với key upload_$filePath, lưu: filePath, chatId, tempMsgId, type (int), isVideo, progress.
Cập nhật progress liên tục vào SharedPreferences.
Quy trình addUploadTask:
Tạo notifier/completer, lưu state.
Kiểm tra file tồn tại.
Gửi ảnh bằng sendInternalImageMessage hoặc file bằng sendInternalFileMessage.
Cập nhật tiến trình (ValueNotifier + SharedPreferences).
Hoàn tất: complete kết quả và xóa state; lỗi: completeError và xóa state.
API chính:
getProgress, getTempDetail, isUploading, getUploadResult, removeTask.
Khôi phục (restoreTasks):
Đọc tất cả upload_* từ SharedPreferences, dựng lại ChatDetail tạm (kèm thông tin user truyền vào), gán progress hiện tại, rồi gọi lại addUploadTask.
Gọi onSuccess khi xong hoặc onError khi lỗi.
Xử lý type:
Map int -> ChatType localImage/localFile/localVideo; isVideo ảnh hưởng thumb/href trong ChatDetail.
*/
class UploadService {
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal();

  final Map<String, ValueNotifier<double>> _uploadProgress = {};
  final Map<String, Completer<ChatDetail>> _uploadTasks = {};
  final Map<String, ChatDetail> _tempDetails = {};

  // Khởi tạo repository (giả sử không cần context)
  final InternalChatRepository _repository = InternalChatRepositoryImp();

  // Thêm task upload
  Future<void> addUploadTask({
    required File file,
    required int chatId,
    required ChatDetail tempDetail,
    required bool isVideo,
    Function(double)? onProgress,
  }) async {
    final filePath = file.path;
    _uploadProgress[filePath] = ValueNotifier<double>(0.0);
    _tempDetails[filePath] = tempDetail;
    _uploadTasks[filePath] = Completer<ChatDetail>();

    // Lưu trạng thái
    await _saveUploadState(filePath, tempDetail, isVideo);

    try {
      if (!file.existsSync()) {
        throw Exception('File $filePath không tồn tại');
      }

      ChatDetail response;
      if (tempDetail.type == ChatType.localImage) {
        response = await _repository.sendInternalImageMessage(
          internalChatId: chatId,
          imagePath: filePath,
          onProgress: (progress) {
            _uploadProgress[filePath]?.value = progress;
            onProgress?.call(progress);
            _updateUploadProgress(filePath, progress);
          },
        );
      } else {
        response = await _repository.sendInternalFileMessage(
          internalChatId: chatId,
          filePath: filePath,
          onProgress: (progress) {
            debugPrint('=====> $progress');
            _uploadProgress[filePath]?.value = progress;
            onProgress?.call(progress);
            _updateUploadProgress(filePath, progress);
          },
        );
      }

      _uploadTasks[filePath]?.complete(response);
      await _removeUploadState(filePath);
    } catch (e, st) {
      debugPrint('Lỗi gửi file $filePath: $e\n$st');
      _uploadTasks[filePath]?.completeError(e, st);
      await _removeUploadState(filePath);
    }
  }

  // Lấy ValueNotifier tiến trình
  ValueNotifier<double>? getProgress(String filePath) =>
      _uploadProgress[filePath];

  // Lấy temp ChatDetail
  ChatDetail? getTempDetail(String filePath) => _tempDetails[filePath];

  // Kiểm tra task đang chạy
  bool isUploading(String filePath) => _uploadTasks.containsKey(filePath);

  // Lấy kết quả task
  Future<ChatDetail> getUploadResult(String filePath) =>
      _uploadTasks[filePath]?.future ?? Future.error('No task for $filePath');

  // Xóa task khi hoàn tất
  void removeTask(String filePath) {
    _uploadProgress.remove(filePath);
    _uploadTasks.remove(filePath);
    _tempDetails.remove(filePath);
  }

  // Lưu trạng thái vào SharedPreferences
  Future<void> _saveUploadState(
      String filePath, ChatDetail tempMsg, bool isVideo) async {
    final prefs = await SharedPreferences.getInstance();
    final uploadData = {
      'filePath': filePath,
      'chatId': tempMsg.internalChatId,
      'tempMsgId': tempMsg.id,
      'type': tempMsg.type, // Lưu trực tiếp giá trị int
      'isVideo': isVideo,
      'progress': 0.0,
    };
    await prefs.setString('upload_$filePath', jsonEncode(uploadData));
  }

  // Cập nhật tiến trình trong SharedPreferences
  Future<void> _updateUploadProgress(String filePath, double progress) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('upload_$filePath');
    if (data != null) {
      final uploadData = jsonDecode(data);
      uploadData['progress'] = progress;
      await prefs.setString('upload_$filePath', jsonEncode(uploadData));
    }
  }

  // Xóa trạng thái khỏi SharedPreferences
  Future<void> _removeUploadState(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('upload_$filePath');
  }

  // Khôi phục các task đang chạy
  Future<void> restoreTasks({
    required int chatId,
    required int senderId,
    required String senderName,
    required String senderUsername,
    required Function(ChatDetail) onSuccess,
    required Function(String, dynamic, StackTrace) onError,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('upload_'));
    for (var key in keys) {
      final data = prefs.getString(key);
      if (data != null) {
        final uploadData = jsonDecode(data);
        final filePath = uploadData['filePath'];
        final isVideo = uploadData['isVideo'] ?? false;
        final typeValue =
            uploadData['type'] as int; // Lấy giá trị int trực tiếp

        // Gán type dựa trên giá trị int
        int chatType;
        if (typeValue == ChatType.localImage) {
          chatType = ChatType.localImage;
        } else if (typeValue == ChatType.localFile) {
          chatType = ChatType.localFile;
        } else if (typeValue == ChatType.localVideo) {
          chatType = ChatType.localVideo;
        } else {
          chatType = ChatType.localFile; // Mặc định nếu không khớp
        }

        final tempMsg = ChatDetail(
          internalChatId: uploadData['chatId'],
          id: uploadData['tempMsgId'],
          type: chatType,
          content: filePath.split('/').last,
          href: filePath,
          thumb: isVideo ? '' : filePath,
          senderId: senderId,
          senderName: senderName,
          user: ChatDetailUser(
            id: senderId,
            username: senderUsername,
            fullName: senderName,
          ),
          createdAtTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          isMsgIn: false,
          loading: true,
        );

        _uploadProgress[filePath] =
            ValueNotifier<double>(uploadData['progress']);
        _tempDetails[filePath] = tempMsg;
        _uploadTasks[filePath] = Completer<ChatDetail>();

        // Tiếp tục task
        addUploadTask(
          file: File(filePath),
          chatId: chatId,
          tempDetail: tempMsg,
          isVideo: isVideo,
          onProgress: (progress) {
            _uploadProgress[filePath]?.value = progress;
          },
        ).then((_) async {
          try {
            final response = await getUploadResult(filePath);
            onSuccess(response);
          } catch (e, st) {
            onError(filePath, e, st);
          }
        });
      }
    }
  }
}