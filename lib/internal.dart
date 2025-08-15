import 'dart:async';
import 'dart:io';
import 'package:chatting/chatting.dart';
import 'package:chatting/src/data/repositories/internal_chat_repository_imp.dart';
import 'package:chatting/src/presentation/blocs/pin_chat/pin_chat_bloc.dart';
import 'package:chatting/src/presentation/blocs/pin_chat/pin_chat_event.dart';
import 'package:chatting/src/presentation/blocs/pin_chat/pin_chat_state.dart';
import 'package:chatting/src/presentation/localization/localization.dart';
import 'package:chatting/src/presentation/widgets/expandable_html_system.dart';
import 'package:chatting/src/presentation/widgets/expandable_markdown.dart';
import 'package:chatting/src/presentation/widgets/popup/popup_action.dart';
import 'package:chatting/src/presentation/widgets/popup/reaction_trigger.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:user_interface/user_interface.dart';
import 'package:chatting/src/presentation/widgets/popup/animated_emoji_popup.dart';
import 'package:chatting/src/presentation/widgets/expandable_text.dart';
import 'package:flutter/gestures.dart';
import '../expandable_html.dart';

class InternalChatItem extends StatefulWidget {
  final ChatDetail main;
  final ChatDetail? previous;
  final ChatDetail? next;
  final bool isMine;
  final Function(double) sy;
  final Function(double) sx;
  final Function(ChatDetail chat) onReply;
  final Function(ChatDetail chat)? onTapQuote;
  final Function(ChatDetail chat)? onResend;
  final Function(String) onUsernameTap;
  final List<ChatUserSuggested> users;
  final Function(int chatDetailId)? onDelete;
  final Function(int chatDetailId, String context)? onEdit;
  final Function(ChatDetail chat, String emoji)? onEmojiSelected;

  const InternalChatItem({
    super.key,
    required this.main,
    this.previous,
    this.next,
    required this.isMine,
    required this.sy,
    required this.sx,
    required this.onReply,
    this.onTapQuote,
    this.onResend,
    required this.onUsernameTap,
    required this.users,
    this.onDelete,
    this.onEdit,
    this.onEmojiSelected,
  });

  @override
  State<InternalChatItem> createState() => _InternalChatItemState();
}

class _InternalChatItemState extends State<InternalChatItem>
    with TickerProviderStateMixin {
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _itemKey = GlobalKey();
  OverlayEntry? _reactionOverlay; // Quản lý OverlayEntry
  bool _dateShow = false;
  bool _previousShownDate = false;
  double _opacity = 0;
  double _minResponseWidth = 0;
  bool _imageError = false;
  bool _imageLoaded = false;
  bool isExpanded = false;
  bool _isSelected = false;

  DateTime get _mainTime => DateTime.fromMillisecondsSinceEpoch(
    widget.main.createdAtTimestamp * 1000,
  );

  DateTime? get _nextTime =>
      widget.next != null
          ? DateTime.fromMillisecondsSinceEpoch(
            widget.next!.createdAtTimestamp * 1000,
          )
          : null;

  DateTime? get _previousTime =>
      widget.previous != null
          ? DateTime.fromMillisecondsSinceEpoch(
            widget.previous!.createdAtTimestamp * 1000,
          )
          : null;

  bool get _checkFirstDate =>
      (widget.next?.senderId == null ||
          (_nextTime != null &&
              _mainTime.differenceTime(_nextTime!).minutes > 30)) ||
      widget.next?.type == ChatType.updated;

  bool get _checkPreviousFirstDate =>
      _previousTime != null &&
      _previousTime!.differenceTime(_mainTime).minutes > 30;

  String _formatDateOnly(BuildContext context, DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year) {
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}";
    } else {
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }
  }

  Future<BaseListResponse<List<String>>> sendEmote(int id, String react) async {
    final response = await InternalChatRepositoryImp().sendEmote(
      id: id,
      react: react,
    );
    return response;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _measureContentWidth();
      }
    });
  }

  @override
  void dispose() {
    _reactionOverlay?.remove();
    _reactionOverlay = null;
    super.dispose();
  }

  void _measureContentWidth() {
    if (widget.main.quoted != null && mounted) {
      final renderBox =
          _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        if (mounted) {
          setState(() {
            _minResponseWidth = renderBox.size.width;
          });
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _measureContentWidth();
          }
        });
      }
    }
  }

  void _showSelectedEmojiEffect(
    BuildContext context,
    String emoji,
    Offset position,
  ) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            left: widget.isMine ? position.dx - 32 : position.dx,
            top: position.dy - 10,
            child: AnimatedEmojiPopup(emoji: emoji),
          ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 600), () {
      overlayEntry?.remove();
      overlayEntry = null;
    });
  }

  bool _isValidImageUrl(String value) {
    return (value.startsWith('http') ||
        value.startsWith('https') &&
            (value.endsWith('.png') ||
                value.endsWith('.jpg') ||
                value.endsWith('.jpeg')));
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    bool isToday =
        _mainTime.year == now.year &&
        _mainTime.month == now.month &&
        _mainTime.day == now.day;
    bool isFirstMessageOfDay =
        _nextTime == null ||
        _mainTime.year != _nextTime!.year ||
        _mainTime.month != _nextTime!.month ||
        _mainTime.day != _nextTime!.day;

    final bool isMineImageSent =
        widget.isMine &&
        (widget.main.type == ChatType.image ||
            widget.main.type == ChatType.localImage) &&
        widget.main.error == true &&
        !widget.main.loading;

    return BlocListener<AppBloc, AppState>(
      listener: _listener,
      child:
          widget.main.type == ChatType.updated && widget.isMine
              ? Padding(
                padding: EdgeInsets.only(bottom: widget.sy(12)),
                child: GestureDetector(
                  onTap: _goToUserDetail,
                  child: Text(
                    ChattingLocalization.of(context).whoUpdated(
                      widget.isMine
                          ? ChattingLocalization.of(context).you
                          : widget.main.user.fullName,
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.black.withOpacity(0.4),
                      fontSize: widget.sy(14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              : Container(
                margin: EdgeInsets.only(
                  left:
                      widget.main.user.id == 3
                          ? 0
                          : widget.isMine
                          ? 0
                          : (widget.previous?.senderId ==
                                  widget.main.senderId &&
                              widget.previous?.type != ChatType.updated &&
                              !_checkPreviousFirstDate)
                          ? 0
                          : widget.sx(10),
                  right:
                      widget.main.user.id == 3
                          ? 0
                          : widget.isMine
                          ? (widget.previous?.senderId ==
                                      widget.main.senderId &&
                                  widget.previous?.type != ChatType.updated &&
                                  !_checkPreviousFirstDate)
                              ? widget.sx(10)
                              : widget.sx(10)
                          : 0,
                  bottom: widget.sy(10),
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  minWidth: 0,
                ),
                child: Column(
                  crossAxisAlignment:
                      widget.isMine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isToday &&
                        isFirstMessageOfDay &&
                        (_checkFirstDate || _dateShow))
                      MyAnimatedSwitcher(
                        child: Container(
                          key: ValueKey(_dateShow),
                          width: double.infinity,
                          alignment: Alignment.center,
                          margin: EdgeInsets.fromLTRB(
                            widget.isMine ? widget.sx(16) : 0,
                            widget.sy(12),
                            widget.isMine ? 0 : widget.sx(16),
                            widget.sy(12),
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.sx(8),
                              vertical: widget.sy(4),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.black.withOpacity(0.2),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(16),
                              ),
                            ),
                            child: Text(
                              _formatDateOnly(context, _mainTime),
                              style: GoogleFonts.inter(
                                color: AppColors.white,
                                fontSize: widget.sy(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.isMine && widget.main.user.id != 3)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: widget.sy(
                                widget.main.loading ||
                                        widget.main.error ||
                                        (widget.previous?.senderId ==
                                                widget.main.senderId &&
                                            widget.previous?.type !=
                                                ChatType.updated)
                                    ? 0
                                    : 10,
                              ),
                              right: widget.sy(8),
                            ),
                            child:
                                (widget.previous?.type != ChatType.updated
                                        ? (widget.previous?.senderId ==
                                                widget.main.senderId &&
                                            !widget.isMine &&
                                            !_previousShownDate &&
                                            !_checkPreviousFirstDate)
                                        : false)
                                    ? Platform.isAndroid || Platform.isIOS
                                        ? SizedBox(width: widget.sy(40))
                                        : SizedBox(width: widget.sy(65))
                                    : GestureDetector(
                                      onTap: _goToUserDetail,
                                      child: MyNetworkAvatar(
                                        widget.main.user.avatar,
                                        tag: widget.main.hashCode,
                                        sy: widget.sy,
                                        sx: widget.sx,
                                        name: widget.main.user.fullName,
                                        size:
                                            Platform.isAndroid || Platform.isIOS
                                                ? widget.sy(30)
                                                : widget.sy(50),
                                      ),
                                    ),
                          ),
                        widget.main.user.id == 3
                            ? const Spacer()
                            : const SizedBox.shrink(),
                        if (widget.main.user.id == 3)
                          Platform.isAndroid || Platform.isIOS
                              ? const SizedBox(width: 0)
                              : SizedBox(width: widget.sx(0)),
                        widget.main.user.id == 3
                            ? BlocBuilder<EmoteBloc, EmoteState>(
                              builder: (context, state) {
                                return Flexible(
                                  flex: 10,
                                  child: GestureDetector(
                                    key: _itemKey,
                                    onTap:
                                        widget.main.error &&
                                                (widget.main.type !=
                                                        ChatType.image &&
                                                    widget.main.type !=
                                                        ChatType.localImage)
                                            ? _resend
                                            : null,
                                    onLongPress: () {
                                      if (mounted) {
                                        setState(() {
                                          _isSelected = true;
                                        });
                                      }
                                      showReactionPopup(
                                        context: context,
                                        targetKey: _itemKey,
                                        item: widget.main,
                                        isMine: widget.isMine,
                                        emotes: state.emote,
                                        onReact:
                                            (emoji) => debugPrint(
                                              "Đã chọn cảm xúc: $emoji",
                                            ),
                                        onRemove:
                                            () => debugPrint("Đã gỡ tin nhắn"),
                                        onForward:
                                            () => debugPrint("Đã chuyển tiếp"),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          widget.isMine
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.9,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            alignment:
                                                widget.isMine
                                                    ? Alignment.centerRight
                                                    : Alignment.centerLeft,
                                            children: [
                                              if (widget.main.user.id != 3)
                                                AnimatedOpacity(
                                                  opacity: _opacity,
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  child: AnimatedContainer(
                                                    duration: Duration(
                                                      milliseconds:
                                                          _opacity == 0
                                                              ? 200
                                                              : 0,
                                                    ),
                                                    padding: EdgeInsets.all(
                                                      widget.sy(8),
                                                    ),
                                                    margin: EdgeInsets.only(
                                                      bottom: widget.sy(
                                                        widget.main.loading ||
                                                                widget
                                                                    .main
                                                                    .error ||
                                                                (widget.previous?.senderId ==
                                                                        widget
                                                                            .main
                                                                            .senderId &&
                                                                    widget
                                                                            .previous
                                                                            ?.type !=
                                                                        ChatType
                                                                            .updated)
                                                            ? 2
                                                            : 16,
                                                      ),
                                                      left:
                                                          widget.isMine
                                                              ? 0
                                                              : widget.sy(
                                                                12 * _opacity,
                                                              ),
                                                      right:
                                                          widget.isMine
                                                              ? widget.sy(
                                                                12 * _opacity,
                                                              )
                                                              : 0,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.08),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Image.asset(
                                                      "assets/icons/${widget.isMine ? "forward_right" : "forward_left"}.png",
                                                      width: widget.sy(20),
                                                      color: Colors.black
                                                          .withOpacity(0.8),
                                                    ),
                                                  ),
                                                ),
                                              Swipable(
                                                verticalSwipe: false,
                                                horizontalDirection:
                                                    widget.isMine
                                                        ? SwipableDirection.end
                                                        : SwipableDirection
                                                            .start,
                                                maxWidth: widget.sy(72),
                                                onSwipeRight: (_) {
                                                  widget.onReply(widget.main);
                                                },
                                                onSwipeRightChanged: (n) {
                                                  if (mounted) {
                                                    setState(() {
                                                      _opacity = n;
                                                    });
                                                  }
                                                },
                                                enable:
                                                    !(widget.main.loading ||
                                                        widget.main.error) &&
                                                    widget.main.user.id != 3,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if ((widget.next?.senderId !=
                                                                widget
                                                                    .main
                                                                    .senderId ||
                                                            _checkFirstDate) &&
                                                        (widget.main.type ==
                                                                ChatType
                                                                    .video ||
                                                            (widget.main.type ==
                                                                    ChatType
                                                                        .image &&
                                                                widget
                                                                        .main
                                                                        .user
                                                                        .id !=
                                                                    3 &&
                                                                !widget
                                                                    .isMine)))
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              bottom: widget.sy(
                                                                4,
                                                              ),
                                                            ),
                                                        child: Container(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal:
                                                                    widget.sx(
                                                                      8,
                                                                    ),
                                                                vertical: widget
                                                                    .sy(4),
                                                              ),
                                                          decoration: const BoxDecoration(
                                                            color:
                                                                AppColors.white,
                                                            borderRadius:
                                                                BorderRadius.all(
                                                                  Radius.circular(
                                                                    16,
                                                                  ),
                                                                ),
                                                          ),
                                                          child: Text(
                                                            widget
                                                                .main
                                                                .user
                                                                .fullName,
                                                            style: GoogleFonts.inter(
                                                              color:
                                                                  Platform.isAndroid ||
                                                                          Platform
                                                                              .isIOS
                                                                      ? const Color(
                                                                        0xFFC35D18,
                                                                      )
                                                                      : Colors
                                                                          .black
                                                                          .withOpacity(
                                                                            0.8,
                                                                          ),
                                                              fontSize: widget
                                                                  .sy(13),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        ConstrainedBox(
                                                          constraints:
                                                              BoxConstraints(
                                                                maxWidth:
                                                                    MediaQuery.of(
                                                                      context,
                                                                    ).size.width *
                                                                    0.9,
                                                              ),
                                                          child: AnimatedContainer(
                                                            clipBehavior:
                                                                Clip.hardEdge,
                                                            margin: EdgeInsets.only(
                                                              bottom:
                                                                  widget.main.type ==
                                                                          ChatType
                                                                              .video
                                                                      ? widget
                                                                          .sy(4)
                                                                      : widget.sy(
                                                                        widget.main.loading ||
                                                                                widget.main.error ||
                                                                                (widget.previous?.senderId ==
                                                                                        widget.main.senderId &&
                                                                                    widget.previous?.type !=
                                                                                        ChatType.updated) ||
                                                                                widget.main.reacts.isNotEmpty
                                                                            ? 2
                                                                            : 16,
                                                                      ),
                                                            ),
                                                            padding:
                                                                widget.main.type ==
                                                                        ChatType
                                                                            .image
                                                                    ? null
                                                                    : EdgeInsets.only(
                                                                      top: widget
                                                                          .sy(
                                                                            2,
                                                                          ),
                                                                    ),
                                                            constraints: BoxConstraints(
                                                              maxWidth:
                                                                  MediaQuery.of(
                                                                    context,
                                                                  ).size.width *
                                                                  (widget.main.type ==
                                                                          ChatType
                                                                              .image
                                                                      ? 0.6
                                                                      : 0.8),
                                                            ),
                                                            foregroundDecoration: BoxDecoration(
                                                              border:
                                                                  widget.main.error ||
                                                                          widget.main.type ==
                                                                              ChatType.system ||
                                                                          widget.main.type ==
                                                                              ChatType.comment ||
                                                                          widget.main.type ==
                                                                              ChatType.follow
                                                                      ? Border.all(
                                                                        width: widget
                                                                            .sy(
                                                                              2,
                                                                            ),
                                                                        color:
                                                                            widget.main.error ==
                                                                                    false
                                                                                ? Colors.red
                                                                                : widget.isMine
                                                                                ? AppColors.logoNude
                                                                                : AppColors.grey,
                                                                      )
                                                                      : null,
                                                              borderRadius: BorderRadius.only(
                                                                topLeft: Radius.circular(
                                                                  widget.sy(
                                                                    widget.next?.senderId ==
                                                                                widget.main.senderId &&
                                                                            !widget.isMine &&
                                                                            !_dateShow &&
                                                                            !_checkFirstDate
                                                                        ? 8
                                                                        : 10,
                                                                  ),
                                                                ),
                                                                topRight: Radius.circular(
                                                                  widget.sy(
                                                                    widget.next?.senderId ==
                                                                                widget.main.senderId &&
                                                                            widget.isMine &&
                                                                            !((widget.next?.loading ??
                                                                                    false) ||
                                                                                (widget.next?.error ??
                                                                                    false)) &&
                                                                            !_dateShow &&
                                                                            !_checkFirstDate
                                                                        ? 8
                                                                        : 10,
                                                                  ),
                                                                ),
                                                                bottomRight: Radius.circular(
                                                                  widget.sy(
                                                                    !(widget.main.loading ||
                                                                                widget.main.error) &&
                                                                            (widget.previous?.type !=
                                                                                    ChatType.updated
                                                                                ? (widget.previous?.senderId ==
                                                                                        widget.main.senderId &&
                                                                                    widget.isMine &&
                                                                                    !_previousShownDate &&
                                                                                    !_checkPreviousFirstDate)
                                                                                : false)
                                                                        ? 8
                                                                        : widget
                                                                            .isMine
                                                                        ? 0
                                                                        : 10,
                                                                  ),
                                                                ),
                                                                bottomLeft:
                                                                    !widget.isMine
                                                                        ? Radius.circular(
                                                                          widget.sy(
                                                                            (widget.previous?.type !=
                                                                                        ChatType.updated
                                                                                    ? (widget.previous?.senderId ==
                                                                                            widget.main.senderId &&
                                                                                        !widget.isMine &&
                                                                                        !_previousShownDate &&
                                                                                        !_checkPreviousFirstDate)
                                                                                    : false)
                                                                                ? 8
                                                                                : 0,
                                                                          ),
                                                                        )
                                                                        : const Radius.circular(
                                                                          10,
                                                                        ),
                                                              ),
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  widget.main.user.id !=
                                                                          3
                                                                      ? widget.main.type ==
                                                                                  ChatType.system ||
                                                                              widget.main.type ==
                                                                                  ChatType.comment ||
                                                                              widget.main.type ==
                                                                                  ChatType.follow
                                                                          ? widget.isMine
                                                                              ? AppColors.nude
                                                                              : AppColors.opalescent
                                                                          : widget
                                                                              .isMine
                                                                          ? Platform.isAndroid ||
                                                                                  Platform.isIOS
                                                                              ? AppColors.nude
                                                                              : const Color(
                                                                                0xFFe5f1ff,
                                                                              )
                                                                          : AppColors
                                                                              .white
                                                                      : Colors
                                                                          .transparent,
                                                              borderRadius: BorderRadius.only(
                                                                topLeft: Radius.circular(
                                                                  widget.sy(
                                                                    widget.next?.senderId ==
                                                                                widget.main.senderId &&
                                                                            !widget.isMine &&
                                                                            !_dateShow &&
                                                                            !_checkFirstDate
                                                                        ? 8
                                                                        : 10,
                                                                  ),
                                                                ),
                                                                topRight: Radius.circular(
                                                                  widget.sy(
                                                                    widget.next?.senderId ==
                                                                                widget.main.senderId &&
                                                                            widget.isMine &&
                                                                            !((widget.next?.loading ??
                                                                                    false) ||
                                                                                (widget.next?.error ??
                                                                                    false)) &&
                                                                            !_dateShow &&
                                                                            !_checkFirstDate
                                                                        ? 8
                                                                        : 10,
                                                                  ),
                                                                ),
                                                                bottomRight: Radius.circular(
                                                                  widget.sy(
                                                                    !(widget.main.loading ||
                                                                                widget.main.error) &&
                                                                            (widget.previous?.type !=
                                                                                    ChatType.updated
                                                                                ? (widget.previous?.senderId ==
                                                                                        widget.main.senderId &&
                                                                                    widget.isMine &&
                                                                                    !_previousShownDate &&
                                                                                    !_checkPreviousFirstDate)
                                                                                : false)
                                                                        ? 8
                                                                        : widget
                                                                            .isMine
                                                                        ? 0
                                                                        : 10,
                                                                  ),
                                                                ),
                                                                bottomLeft:
                                                                    !widget.isMine
                                                                        ? Radius.circular(
                                                                          widget.sy(
                                                                            (widget.previous?.type !=
                                                                                        ChatType.updated
                                                                                    ? (widget.previous?.senderId ==
                                                                                            widget.main.senderId &&
                                                                                        !widget.isMine &&
                                                                                        !_previousShownDate &&
                                                                                        !_checkPreviousFirstDate)
                                                                                    : false)
                                                                                ? 8
                                                                                : 0,
                                                                          ),
                                                                        )
                                                                        : const Radius.circular(
                                                                          10,
                                                                        ),
                                                              ),
                                                              boxShadow:
                                                                  widget.main.user.id !=
                                                                          3
                                                                      ? [
                                                                        BoxShadow(
                                                                          color: Colors.grey.withOpacity(
                                                                            0.5,
                                                                          ),
                                                                          spreadRadius:
                                                                              0.1,
                                                                          blurRadius:
                                                                              0.5,
                                                                          offset: const Offset(
                                                                            0,
                                                                            1,
                                                                          ),
                                                                        ),
                                                                      ]
                                                                      : null,
                                                            ),
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      200,
                                                                ),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                if ((widget.next?.senderId !=
                                                                            widget.main.senderId ||
                                                                        _checkFirstDate) &&
                                                                    !widget
                                                                        .isMine &&
                                                                    widget
                                                                            .main
                                                                            .type !=
                                                                        ChatType
                                                                            .video &&
                                                                    widget
                                                                            .main
                                                                            .type !=
                                                                        ChatType
                                                                            .image)
                                                                  widget.main.user.id !=
                                                                          3
                                                                      ? Padding(
                                                                        padding: EdgeInsets.only(
                                                                          left: widget.sx(
                                                                            16,
                                                                          ),
                                                                          right: widget.sx(
                                                                            16,
                                                                          ),
                                                                          top: widget.sy(
                                                                            8,
                                                                          ),
                                                                        ),
                                                                        child: Text(
                                                                          widget
                                                                              .main
                                                                              .user
                                                                              .fullName,
                                                                          style: GoogleFonts.inter(
                                                                            color:
                                                                                Platform.isAndroid ||
                                                                                        Platform.isIOS
                                                                                    ? const Color(
                                                                                      0xFFC35D18,
                                                                                    )
                                                                                    : Colors.black.withOpacity(
                                                                                      0.8,
                                                                                    ),
                                                                            fontSize: widget.sy(
                                                                              13,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      )
                                                                      : const SizedBox.shrink(),
                                                                if (widget
                                                                        .main
                                                                        .quoted !=
                                                                    null)
                                                                  GestureDetector(
                                                                    behavior:
                                                                        HitTestBehavior
                                                                            .opaque,
                                                                    onTap:
                                                                        () => widget.onTapQuote?.call(
                                                                          widget
                                                                              .main
                                                                              .quoted!,
                                                                        ),
                                                                    child: Padding(
                                                                      padding: EdgeInsets.only(
                                                                        left: widget
                                                                            .sx(
                                                                              12,
                                                                            ),
                                                                        right:
                                                                            widget.isMine
                                                                                ? 0
                                                                                : widget.sx(12),
                                                                        top: widget
                                                                            .sx(
                                                                              8,
                                                                            ),
                                                                      ),
                                                                      child: Row(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Container(
                                                                            width: widget.sx(
                                                                              4,
                                                                            ),
                                                                            height: widget.sy(
                                                                              58,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              color:
                                                                                  widget.isMine
                                                                                      ? Colors.orange.withOpacity(
                                                                                        0.7,
                                                                                      )
                                                                                      : Colors.grey,
                                                                              borderRadius: BorderRadius.only(
                                                                                topLeft: Radius.circular(
                                                                                  widget.sy(
                                                                                    8,
                                                                                  ),
                                                                                ),
                                                                                bottomLeft: Radius.circular(
                                                                                  widget.sy(
                                                                                    8,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width: widget.sx(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                          Expanded(
                                                                            child: Container(
                                                                              padding: EdgeInsets.only(
                                                                                left: widget.sx(
                                                                                  12,
                                                                                ),
                                                                                right:
                                                                                    widget.isMine
                                                                                        ? 0
                                                                                        : widget.sx(
                                                                                          12,
                                                                                        ),
                                                                                top: widget.sy(
                                                                                  8,
                                                                                ),
                                                                                bottom: widget.sy(
                                                                                  8,
                                                                                ),
                                                                              ),
                                                                              decoration: BoxDecoration(
                                                                                color:
                                                                                    widget.isMine
                                                                                        ? Colors.white.withOpacity(
                                                                                          0.4,
                                                                                        )
                                                                                        : Colors.grey.withOpacity(
                                                                                          0.2,
                                                                                        ),
                                                                                borderRadius: BorderRadius.only(
                                                                                  topRight: Radius.circular(
                                                                                    widget.sy(
                                                                                      8,
                                                                                    ),
                                                                                  ),
                                                                                  bottomRight: Radius.circular(
                                                                                    widget.sy(
                                                                                      8,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              child: ConstrainedBox(
                                                                                constraints: BoxConstraints(
                                                                                  maxWidth:
                                                                                      MediaQuery.of(
                                                                                        context,
                                                                                      ).size.width *
                                                                                      0.7,
                                                                                ),
                                                                                child: Row(
                                                                                  crossAxisAlignment:
                                                                                      CrossAxisAlignment.start,
                                                                                  children: [
                                                                                    if ((widget.main.quoted!.type ==
                                                                                                ChatType.image ||
                                                                                            widget.main.quoted!.type ==
                                                                                                ChatType.video) &&
                                                                                        widget.main.quoted!.href.isNotEmpty)
                                                                                      Padding(
                                                                                        padding: EdgeInsets.only(
                                                                                          right: widget.sx(
                                                                                            8,
                                                                                          ),
                                                                                        ),
                                                                                        child: CachedNetworkImage(
                                                                                          imageUrl:
                                                                                              widget.main.quoted!.type ==
                                                                                                      ChatType.video
                                                                                                  ? widget.main.quoted!.thumb
                                                                                                  : widget.main.quoted!.href,
                                                                                          width: widget.sx(
                                                                                            32,
                                                                                          ),
                                                                                          height: widget.sx(
                                                                                            32,
                                                                                          ),
                                                                                          fit:
                                                                                              BoxFit.contain,
                                                                                          errorWidget:
                                                                                              _imageErrorResponse,
                                                                                        ),
                                                                                      ),
                                                                                    Expanded(
                                                                                      child: Column(
                                                                                        mainAxisSize:
                                                                                            MainAxisSize.min,
                                                                                        crossAxisAlignment:
                                                                                            CrossAxisAlignment.start,
                                                                                        children: [
                                                                                          Text(
                                                                                            widget.isMine &&
                                                                                                    widget.main.senderId ==
                                                                                                        widget.main.quoted!.senderId
                                                                                                ? ChattingLocalization.of(
                                                                                                  context,
                                                                                                ).you
                                                                                                : widget.main.quoted!.user.fullName,
                                                                                            style: GoogleFonts.inter(
                                                                                              color:
                                                                                                  Colors.black,
                                                                                              fontSize: widget.sy(
                                                                                                14,
                                                                                              ),
                                                                                              fontWeight:
                                                                                                  FontWeight.w600,
                                                                                            ),
                                                                                            maxLines:
                                                                                                1,
                                                                                            overflow:
                                                                                                TextOverflow.ellipsis,
                                                                                          ),
                                                                                          SizedBox(
                                                                                            height: widget.sy(
                                                                                              2,
                                                                                            ),
                                                                                          ),
                                                                                          Text(
                                                                                            "${widget.main.quoted!.type == ChatType.image
                                                                                                ? "${ChattingLocalization.of(context).image} "
                                                                                                : widget.main.quoted!.type == ChatType.video
                                                                                                ? "${ChattingLocalization.of(context).video} "
                                                                                                : widget.main.quoted!.type == ChatType.file
                                                                                                ? "${ChattingLocalization.of(context).file} "
                                                                                                : ""}${parse(widget.main.quoted!.content).documentElement!.text}",
                                                                                            style: GoogleFonts.inter(
                                                                                              color:
                                                                                                  Colors.black,
                                                                                              fontSize: widget.sy(
                                                                                                14,
                                                                                              ),
                                                                                            ),
                                                                                            maxLines:
                                                                                                1,
                                                                                            overflow:
                                                                                                TextOverflow.ellipsis,
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ConstrainedBox(
                                                                  constraints: BoxConstraints(
                                                                    minWidth: 0,
                                                                    maxWidth:
                                                                        Platform.isMacOS ||
                                                                                Platform.isWindows
                                                                            ? MediaQuery.of(
                                                                                  context,
                                                                                ).size.width /
                                                                                3
                                                                            : MediaQuery.of(context).size.width *
                                                                                0.8,
                                                                  ),
                                                                  child: Container(
                                                                    key:
                                                                        _contentKey,
                                                                    child: _buildImageOrOther(
                                                                      context,
                                                                      isMineImageSent,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        if (widget
                                                                .main
                                                                .reacts
                                                                .isNotEmpty &&
                                                            widget
                                                                    .main
                                                                    .user
                                                                    .id !=
                                                                3)
                                                          Positioned(
                                                            bottom: widget.sy(
                                                              -8,
                                                            ),
                                                            right:
                                                                widget.isMine
                                                                    ? widget.sx(
                                                                      2,
                                                                    )
                                                                    : widget.sx(
                                                                      8,
                                                                    ),
                                                            child: BlocBuilder<
                                                              EmoteBloc,
                                                              EmoteState
                                                            >(
                                                              builder: (
                                                                context,
                                                                state,
                                                              ) {
                                                                return ReactionTrigger(
                                                                  sx: widget.sx,
                                                                  sy: widget.sy,
                                                                  emote:
                                                                      state
                                                                          .emote,
                                                                  onSelected: (
                                                                    emoji,
                                                                  ) {
                                                                    sendEmote(
                                                                      widget
                                                                          .main
                                                                          .id,
                                                                      emoji,
                                                                    );
                                                                  },
                                                                  react:
                                                                      widget
                                                                              .main
                                                                              .reacts
                                                                              .isEmpty
                                                                          ? null
                                                                          : widget
                                                                              .main
                                                                              .reacts
                                                                              .last,
                                                                  main:
                                                                      widget
                                                                          .main,
                                                                  onEmojiSelected: (
                                                                    chat,
                                                                    emoji,
                                                                    position,
                                                                  ) {
                                                                    if (mounted) {
                                                                      _showSelectedEmojiEffect(
                                                                        context,
                                                                        emoji,
                                                                        position,
                                                                      );
                                                                      widget
                                                                          .onEmojiSelected
                                                                          ?.call(
                                                                            chat,
                                                                            emoji,
                                                                          );
                                                                    }
                                                                  },
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    if (widget.main.type ==
                                                            ChatType.video ||
                                                        widget.main.type ==
                                                            ChatType
                                                                .localFile ||
                                                        (widget.main.type ==
                                                                ChatType
                                                                    .image &&
                                                            widget
                                                                    .main
                                                                    .user
                                                                    .id !=
                                                                3))
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      widget.sx(
                                                                        8,
                                                                      ),
                                                                  vertical:
                                                                      widget.sy(
                                                                        4,
                                                                      ),
                                                                ),
                                                            decoration: const BoxDecoration(
                                                              color:
                                                                  AppColors
                                                                      .white,
                                                              borderRadius:
                                                                  BorderRadius.all(
                                                                    Radius.circular(
                                                                      16,
                                                                    ),
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              _mainTime
                                                                  .shortHintDateWithTime2(
                                                                    context,
                                                                  ),
                                                              style: GoogleFonts.inter(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                      0.8,
                                                                    ),
                                                                fontSize: widget
                                                                    .sy(12),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    SizedBox(
                                                      height: widget.sy(8),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (widget.main.loading ||
                                            widget.main.error)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: widget.sy(
                                                widget.previous?.senderId ==
                                                            widget
                                                                .main
                                                                .senderId &&
                                                        widget.previous?.type !=
                                                            ChatType.updated
                                                    ? 4
                                                    : 16,
                                              ),
                                            ),
                                            child: Text(
                                              widget.main.loading
                                                  ? ChattingLocalization.of(
                                                    context,
                                                  ).sending
                                                  : widget.main.error == true
                                                  ? 'Đã gửi'
                                                  : 'Gửi lỗi',
                                              style: GoogleFonts.inter(
                                                color:
                                                    widget.main.loading
                                                        ? Colors.black
                                                            .withOpacity(0.4)
                                                        : widget.main.error ==
                                                            true
                                                        ? Colors.black
                                                            .withOpacity(0.4)
                                                        : Colors.red,
                                                fontSize: widget.sy(12),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                            : Expanded(
                              child: BlocBuilder<EmoteBloc, EmoteState>(
                                builder: (context, state) {
                                  return Container(
                                    child: GestureDetector(
                                      key: _itemKey,
                                      onTap:
                                          widget.main.error &&
                                                  (widget.main.type !=
                                                          ChatType.image &&
                                                      widget.main.type !=
                                                          ChatType.localImage)
                                              ? _resend
                                              : null,
                                      onLongPress: () {
                                        if (mounted) {
                                          setState(() {
                                            _isSelected = true;
                                          });
                                        }
                                        showReactionPopup(
                                          context: context,
                                          targetKey: _itemKey,
                                          item: widget.main,
                                          isMine: widget.isMine,
                                          emotes: state.emote,
                                          onReact:
                                              (emoji) => debugPrint(
                                                "Đã chọn cảm xúc: $emoji",
                                              ),
                                          onRemove:
                                              () =>
                                                  debugPrint("Đã gỡ tin nhắn"),
                                          onForward:
                                              () =>
                                                  debugPrint("Đã chuyển tiếp"),
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            widget.isMine
                                                ? CrossAxisAlignment.end
                                                : CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              alignment:
                                                  widget.isMine
                                                      ? Alignment.centerRight
                                                      : Alignment.centerLeft,
                                              children: [
                                                if (widget.main.user.id != 3)
                                                  AnimatedOpacity(
                                                    opacity: _opacity,
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    child: AnimatedContainer(
                                                      duration: Duration(
                                                        milliseconds:
                                                            _opacity == 0
                                                                ? 200
                                                                : 0,
                                                      ),
                                                      padding: EdgeInsets.all(
                                                        widget.sy(8),
                                                      ),
                                                      margin: EdgeInsets.only(
                                                        bottom: widget.sy(
                                                          widget.main.loading ||
                                                                  widget
                                                                      .main
                                                                      .error ||
                                                                  (widget.previous?.senderId ==
                                                                          widget
                                                                              .main
                                                                              .senderId &&
                                                                      widget.previous?.type !=
                                                                          ChatType
                                                                              .updated)
                                                              ? 2
                                                              : 16,
                                                        ),
                                                        left:
                                                            widget.isMine
                                                                ? 0
                                                                : widget.sy(
                                                                  12 * _opacity,
                                                                ),
                                                        right:
                                                            widget.isMine
                                                                ? widget.sy(
                                                                  12 * _opacity,
                                                                )
                                                                : 0,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withOpacity(0.08),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Image.asset(
                                                        "assets/icons/${widget.isMine ? "forward_right" : "forward_left"}.png",
                                                        width: widget.sy(20),
                                                        color: Colors.black
                                                            .withOpacity(0.8),
                                                      ),
                                                    ),
                                                  ),
                                                Swipable(
                                                  verticalSwipe: false,
                                                  horizontalDirection:
                                                      widget.isMine
                                                          ? SwipableDirection
                                                              .end
                                                          : SwipableDirection
                                                              .start,
                                                  maxWidth: widget.sy(72),
                                                  onSwipeRight: (_) {
                                                    widget.onReply(widget.main);
                                                  },
                                                  onSwipeRightChanged: (n) {
                                                    if (mounted) {
                                                      setState(() {
                                                        _opacity = n;
                                                      });
                                                    }
                                                  },
                                                  enable:
                                                      !(widget.main.loading ||
                                                          widget.main.error) &&
                                                      widget.main.user.id != 3,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      if ((widget.next?.senderId !=
                                                                  widget
                                                                      .main
                                                                      .senderId ||
                                                              _checkFirstDate) &&
                                                          (widget.main.type ==
                                                                  ChatType
                                                                      .video ||
                                                              (widget.main.type ==
                                                                      ChatType
                                                                          .image &&
                                                                  widget
                                                                          .main
                                                                          .user
                                                                          .id !=
                                                                      3 &&
                                                                  !widget
                                                                      .isMine)))
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                bottom: widget
                                                                    .sy(4),
                                                              ),
                                                          child: Container(
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      widget.sx(
                                                                        8,
                                                                      ),
                                                                  vertical:
                                                                      widget.sy(
                                                                        4,
                                                                      ),
                                                                ),
                                                            decoration: const BoxDecoration(
                                                              color:
                                                                  AppColors
                                                                      .white,
                                                              borderRadius:
                                                                  BorderRadius.all(
                                                                    Radius.circular(
                                                                      16,
                                                                    ),
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              widget
                                                                  .main
                                                                  .user
                                                                  .fullName,
                                                              style: GoogleFonts.inter(
                                                                color:
                                                                    Platform.isAndroid ||
                                                                            Platform.isIOS
                                                                        ? const Color(
                                                                          0xFFC35D18,
                                                                        )
                                                                        : Colors
                                                                            .black
                                                                            .withOpacity(
                                                                              0.8,
                                                                            ),
                                                                fontSize: widget
                                                                    .sy(13),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          ConstrainedBox(
                                                            constraints: BoxConstraints(
                                                              maxWidth:
                                                                  Platform.isMacOS ||
                                                                          Platform
                                                                              .isWindows
                                                                      ? MediaQuery.of(
                                                                            context,
                                                                          ).size.width /
                                                                          3
                                                                      : MediaQuery.of(
                                                                            context,
                                                                          ).size.width *
                                                                          0.85,
                                                            ),
                                                            child: AnimatedContainer(
                                                              clipBehavior:
                                                                  Clip.hardEdge,
                                                              margin: EdgeInsets.only(
                                                                bottom:
                                                                    widget.main.type ==
                                                                                ChatType.video ||
                                                                            widget.main.type ==
                                                                                ChatType.image ||
                                                                            widget.main.type ==
                                                                                ChatType.localImage ||
                                                                            widget.main.type ==
                                                                                ChatType.localVideo
                                                                        ? widget
                                                                            .sy(
                                                                              4,
                                                                            )
                                                                        : widget.sy(
                                                                          widget.main.loading ||
                                                                                  widget.main.error ||
                                                                                  (widget.previous?.senderId ==
                                                                                          widget.main.senderId &&
                                                                                      widget.previous?.type !=
                                                                                          ChatType.updated) ||
                                                                                  widget.main.reacts.isNotEmpty
                                                                              ? 2
                                                                              : 16,
                                                                        ),
                                                              ),
                                                              padding:
                                                                  widget.main.type ==
                                                                              ChatType.image ||
                                                                          widget.main.type ==
                                                                              ChatType.video ||
                                                                          widget.main.type ==
                                                                              ChatType.file ||
                                                                          widget.main.type ==
                                                                              ChatType.localFile ||
                                                                          widget.main.type ==
                                                                              ChatType.localImage ||
                                                                          widget.main.type ==
                                                                              ChatType.localVideo
                                                                      ? null
                                                                      : EdgeInsets.only(
                                                                        top: widget
                                                                            .sy(
                                                                              2,
                                                                            ),
                                                                      ),
                                                              constraints: BoxConstraints(
                                                                maxWidth:
                                                                    MediaQuery.of(
                                                                      context,
                                                                    ).size.width *
                                                                    (widget.main.type ==
                                                                            ChatType.image
                                                                        ? 0.6
                                                                        : 0.8),
                                                              ),
                                                              foregroundDecoration: BoxDecoration(
                                                                border:
                                                                    widget.main.error ||
                                                                            widget.main.type ==
                                                                                ChatType.system ||
                                                                            widget.main.type ==
                                                                                ChatType.comment ||
                                                                            widget.main.type ==
                                                                                ChatType.follow
                                                                        ? Border.all(
                                                                          width:
                                                                              widget.sy(
                                                                                2,
                                                                              ),
                                                                          color:
                                                                              widget.main.error ==
                                                                                      true
                                                                                  ? Colors.red
                                                                                  : widget.isMine
                                                                                  ? AppColors.logoNude
                                                                                  : AppColors.grey,
                                                                        )
                                                                        : null,
                                                                borderRadius: BorderRadius.only(
                                                                  topLeft: Radius.circular(
                                                                    widget.sy(
                                                                      widget.next?.senderId ==
                                                                                  widget.main.senderId &&
                                                                              !widget.isMine &&
                                                                              !_dateShow &&
                                                                              !_checkFirstDate
                                                                          ? 8
                                                                          : 10,
                                                                    ),
                                                                  ),
                                                                  topRight: Radius.circular(
                                                                    widget.sy(
                                                                      widget.next?.senderId ==
                                                                                  widget.main.senderId &&
                                                                              widget.isMine &&
                                                                              !((widget.next?.loading ??
                                                                                      false) ||
                                                                                  (widget.next?.error ??
                                                                                      false)) &&
                                                                              !_dateShow &&
                                                                              !_checkFirstDate
                                                                          ? 8
                                                                          : 10,
                                                                    ),
                                                                  ),
                                                                  bottomRight: Radius.circular(
                                                                    widget.sy(
                                                                      !(widget.main.loading ||
                                                                                  widget.main.error) &&
                                                                              (widget.previous?.type !=
                                                                                      ChatType.updated
                                                                                  ? (widget.previous?.senderId ==
                                                                                          widget.main.senderId &&
                                                                                      widget.isMine &&
                                                                                      !_previousShownDate &&
                                                                                      !_checkPreviousFirstDate)
                                                                                  : false)
                                                                          ? 8
                                                                          : widget
                                                                              .isMine
                                                                          ? 0
                                                                          : 10,
                                                                    ),
                                                                  ),
                                                                  bottomLeft:
                                                                      !widget.isMine
                                                                          ? Radius.circular(
                                                                            widget.sy(
                                                                              (widget.previous?.type !=
                                                                                          ChatType.updated
                                                                                      ? (widget.previous?.senderId ==
                                                                                              widget.main.senderId &&
                                                                                          !widget.isMine &&
                                                                                          !_previousShownDate &&
                                                                                          !_checkPreviousFirstDate)
                                                                                      : false)
                                                                                  ? 8
                                                                                  : 0,
                                                                            ),
                                                                          )
                                                                          : const Radius.circular(
                                                                            10,
                                                                          ),
                                                                ),
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    widget.main.user.id !=
                                                                            3
                                                                        ? widget.main.type ==
                                                                                    ChatType.system ||
                                                                                widget.main.type ==
                                                                                    ChatType.comment ||
                                                                                widget.main.type ==
                                                                                    ChatType.follow
                                                                            ? widget.isMine
                                                                                ? AppColors.nude
                                                                                : AppColors.opalescent
                                                                            : widget.isMine
                                                                            ? Platform.isAndroid ||
                                                                                    Platform.isIOS
                                                                                ? AppColors.nude
                                                                                : const Color(
                                                                                  0xFFe5f1ff,
                                                                                )
                                                                            : AppColors.white
                                                                        : Colors
                                                                            .transparent,
                                                                borderRadius: BorderRadius.only(
                                                                  topLeft: Radius.circular(
                                                                    widget.sy(
                                                                      widget.next?.senderId ==
                                                                                  widget.main.senderId &&
                                                                              !widget.isMine &&
                                                                              !_dateShow &&
                                                                              !_checkFirstDate
                                                                          ? 8
                                                                          : 10,
                                                                    ),
                                                                  ),
                                                                  topRight: Radius.circular(
                                                                    widget.sy(
                                                                      widget.next?.senderId ==
                                                                                  widget.main.senderId &&
                                                                              widget.isMine &&
                                                                              !((widget.next?.loading ??
                                                                                      false) ||
                                                                                  (widget.next?.error ??
                                                                                      false)) &&
                                                                              !_dateShow &&
                                                                              !_checkFirstDate
                                                                          ? 8
                                                                          : 10,
                                                                    ),
                                                                  ),
                                                                  bottomRight: Radius.circular(
                                                                    widget.sy(
                                                                      !(widget.main.loading ||
                                                                                  widget.main.error) &&
                                                                              (widget.previous?.type !=
                                                                                      ChatType.updated
                                                                                  ? (widget.previous?.senderId ==
                                                                                          widget.main.senderId &&
                                                                                      widget.isMine &&
                                                                                      !_previousShownDate &&
                                                                                      !_checkPreviousFirstDate)
                                                                                  : false)
                                                                          ? 8
                                                                          : widget
                                                                              .isMine
                                                                          ? 0
                                                                          : 10,
                                                                    ),
                                                                  ),
                                                                  bottomLeft:
                                                                      !widget.isMine
                                                                          ? Radius.circular(
                                                                            widget.sy(
                                                                              (widget.previous?.type !=
                                                                                          ChatType.updated
                                                                                      ? (widget.previous?.senderId ==
                                                                                              widget.main.senderId &&
                                                                                          !widget.isMine &&
                                                                                          !_previousShownDate &&
                                                                                          !_checkPreviousFirstDate)
                                                                                      : false)
                                                                                  ? 8
                                                                                  : 0,
                                                                            ),
                                                                          )
                                                                          : const Radius.circular(
                                                                            10,
                                                                          ),
                                                                ),
                                                                boxShadow:
                                                                    widget.main.user.id !=
                                                                            3
                                                                        ? [
                                                                          BoxShadow(
                                                                            color: Colors.grey.withOpacity(
                                                                              0.5,
                                                                            ),
                                                                            spreadRadius:
                                                                                0.1,
                                                                            blurRadius:
                                                                                0.5,
                                                                            offset: const Offset(
                                                                              0,
                                                                              1,
                                                                            ),
                                                                          ),
                                                                        ]
                                                                        : null,
                                                              ),
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        200,
                                                                  ),
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  if ((widget.next?.senderId !=
                                                                              widget.main.senderId ||
                                                                          _checkFirstDate) &&
                                                                      !widget
                                                                          .isMine &&
                                                                      widget.main.type !=
                                                                          ChatType
                                                                              .video &&
                                                                      widget.main.type !=
                                                                          ChatType
                                                                              .image)
                                                                    widget.main.user.id !=
                                                                            3
                                                                        ? Padding(
                                                                          padding: EdgeInsets.only(
                                                                            left: widget.sx(
                                                                              16,
                                                                            ),
                                                                            right: widget.sx(
                                                                              16,
                                                                            ),
                                                                            top: widget.sy(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                          child: Text(
                                                                            widget.main.user.fullName,
                                                                            style: GoogleFonts.inter(
                                                                              color:
                                                                                  Platform.isAndroid ||
                                                                                          Platform.isIOS
                                                                                      ? const Color(
                                                                                        0xFFC35D18,
                                                                                      )
                                                                                      : Colors.black.withOpacity(
                                                                                        0.8,
                                                                                      ),
                                                                              fontSize: widget.sy(
                                                                                13,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        )
                                                                        : const SizedBox.shrink(),
                                                                  if (widget.main.quoted !=
                                                                          null &&
                                                                      widget.main.loading ==
                                                                          false &&
                                                                      widget
                                                                          .main
                                                                          .quoted!
                                                                          .content
                                                                          .isNotEmpty &&
                                                                      widget
                                                                          .main
                                                                          .quoted!
                                                                          .user
                                                                          .fullName
                                                                          .isNotEmpty)
                                                                    GestureDetector(
                                                                      behavior:
                                                                          HitTestBehavior
                                                                              .opaque,
                                                                      onTap:
                                                                          () => widget.onTapQuote?.call(
                                                                            widget.main.quoted!,
                                                                          ),
                                                                      child: Padding(
                                                                        padding: EdgeInsets.only(
                                                                          left: widget.sx(
                                                                            12,
                                                                          ),
                                                                          right:
                                                                              widget.isMine
                                                                                  ? widget.sx(
                                                                                    12,
                                                                                  )
                                                                                  : widget.sx(12),
                                                                          top: widget.sx(
                                                                            8,
                                                                          ),
                                                                        ),
                                                                        child: Row(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Container(
                                                                              width: widget.sx(
                                                                                4,
                                                                              ),
                                                                              height: widget.sy(
                                                                                58,
                                                                              ),
                                                                              decoration: BoxDecoration(
                                                                                color:
                                                                                    widget.isMine
                                                                                        ? Colors.orange.withOpacity(
                                                                                          0.7,
                                                                                        )
                                                                                        : Colors.grey,
                                                                                borderRadius: BorderRadius.only(
                                                                                  topLeft: Radius.circular(
                                                                                    widget.sy(
                                                                                      10,
                                                                                    ),
                                                                                  ),
                                                                                  bottomLeft: Radius.circular(
                                                                                    widget.sy(
                                                                                      10,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Flexible(
                                                                              fit:
                                                                                  FlexFit.loose,
                                                                              child: ConstrainedBox(
                                                                                constraints: BoxConstraints(
                                                                                  maxWidth:
                                                                                      Platform.isMacOS ||
                                                                                              Platform.isWindows
                                                                                          ? MediaQuery.of(
                                                                                                context,
                                                                                              ).size.width /
                                                                                              3
                                                                                          : MediaQuery.of(
                                                                                                context,
                                                                                              ).size.width *
                                                                                              0.8,
                                                                                  minWidth:
                                                                                      0,
                                                                                ),
                                                                                child: Container(
                                                                                  padding: EdgeInsets.symmetric(
                                                                                    horizontal:
                                                                                        8,
                                                                                    vertical:
                                                                                        8,
                                                                                  ),
                                                                                  // padding: EdgeInsets.only(
                                                                                  //   left: widget.sx(12),
                                                                                  //   right: widget.isMine ? widget.sx(4) : widget.sx(12),
                                                                                  //   top: widget.sy(8),
                                                                                  //   bottom: widget.sy(8),
                                                                                  // ),
                                                                                  decoration: BoxDecoration(
                                                                                    color:
                                                                                        widget.isMine
                                                                                            ? Colors.white.withOpacity(
                                                                                              0.4,
                                                                                            )
                                                                                            : Colors.grey.withOpacity(
                                                                                              0.2,
                                                                                            ),
                                                                                    borderRadius: BorderRadius.only(
                                                                                      topRight: Radius.circular(
                                                                                        widget.sy(
                                                                                          8,
                                                                                        ),
                                                                                      ),
                                                                                      bottomRight: Radius.circular(
                                                                                        widget.sy(
                                                                                          8,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  child: Row(
                                                                                    mainAxisAlignment:
                                                                                        MainAxisAlignment.center,
                                                                                    mainAxisSize:
                                                                                        MainAxisSize.min,
                                                                                    crossAxisAlignment:
                                                                                        CrossAxisAlignment.start,
                                                                                    children: [
                                                                                      if ((widget.main.quoted!.type ==
                                                                                                  ChatType.image ||
                                                                                              widget.main.quoted!.type ==
                                                                                                  ChatType.video) &&
                                                                                          widget.main.quoted!.href.isNotEmpty)
                                                                                        CachedNetworkImage(
                                                                                          imageUrl:
                                                                                              widget.main.quoted!.type ==
                                                                                                      ChatType.video
                                                                                                  ? widget.main.quoted!.thumb
                                                                                                  : widget.main.quoted!.href,
                                                                                          width: widget.sx(
                                                                                            32,
                                                                                          ),
                                                                                          height: widget.sx(
                                                                                            32,
                                                                                          ),
                                                                                          fit:
                                                                                              BoxFit.contain,
                                                                                          errorWidget:
                                                                                              _imageErrorResponse,
                                                                                        ),
                                                                                      Flexible(
                                                                                        fit:
                                                                                            FlexFit.loose,
                                                                                        child: Column(
                                                                                          mainAxisSize:
                                                                                              MainAxisSize.min,
                                                                                          crossAxisAlignment:
                                                                                              CrossAxisAlignment.start,
                                                                                          children: [
                                                                                            Text(
                                                                                              widget.isMine &&
                                                                                                      widget.main.senderId ==
                                                                                                          widget.main.quoted!.senderId
                                                                                                  ? ChattingLocalization.of(
                                                                                                    context,
                                                                                                  ).you
                                                                                                  : widget.main.quoted!.user.fullName,
                                                                                              style: GoogleFonts.inter(
                                                                                                color:
                                                                                                    Colors.black,
                                                                                                fontSize: widget.sy(
                                                                                                  14,
                                                                                                ),
                                                                                                fontWeight:
                                                                                                    FontWeight.w600,
                                                                                              ),
                                                                                              maxLines:
                                                                                                  1,
                                                                                              overflow:
                                                                                                  TextOverflow.ellipsis,
                                                                                            ),
                                                                                            SizedBox(
                                                                                              height: widget.sy(
                                                                                                2,
                                                                                              ),
                                                                                            ),
                                                                                            Text(
                                                                                              "${widget.main.quoted!.type == ChatType.image
                                                                                                  ? "${ChattingLocalization.of(context).image} "
                                                                                                  : widget.main.quoted!.type == ChatType.video
                                                                                                  ? "${ChattingLocalization.of(context).video} "
                                                                                                  : widget.main.quoted!.type == ChatType.file
                                                                                                  ? "${ChattingLocalization.of(context).file} "
                                                                                                  : ""}${parse(widget.main.quoted!.content).documentElement!.text}",
                                                                                              style: GoogleFonts.inter(
                                                                                                color:
                                                                                                    Colors.black,
                                                                                                fontSize: widget.sy(
                                                                                                  14,
                                                                                                ),
                                                                                              ),
                                                                                              maxLines:
                                                                                                  1,
                                                                                              overflow:
                                                                                                  TextOverflow.ellipsis,
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ConstrainedBox(
                                                                    constraints: BoxConstraints(
                                                                      minWidth:
                                                                          0,
                                                                      maxWidth:
                                                                          Platform.isMacOS ||
                                                                                  Platform.isWindows
                                                                              ? MediaQuery.of(
                                                                                    context,
                                                                                  ).size.width /
                                                                                  2
                                                                              : MediaQuery.of(context).size.width *
                                                                                  0.85,
                                                                    ),
                                                                    child: Container(
                                                                      key:
                                                                          _contentKey,
                                                                      padding:
                                                                          (widget.main.type ==
                                                                                      ChatType.image ||
                                                                                  widget.main.type ==
                                                                                      ChatType.file ||
                                                                                  widget.main.type ==
                                                                                      ChatType.video ||
                                                                                  widget.main.type ==
                                                                                      ChatType.localImage ||
                                                                                  widget.main.type ==
                                                                                      ChatType.localVideo ||
                                                                                  widget.main.type ==
                                                                                      ChatType.localFile)
                                                                              ? null
                                                                              : EdgeInsets.only(
                                                                                top:
                                                                                    0,
                                                                                left: widget.sx(
                                                                                  12,
                                                                                ),
                                                                                right: widget.sx(
                                                                                  12,
                                                                                ),
                                                                                bottom: widget.sy(
                                                                                  4,
                                                                                ),
                                                                              ),
                                                                      child: _buildImageOrOther(
                                                                        context,
                                                                        isMineImageSent,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          if (widget
                                                                  .main
                                                                  .reacts
                                                                  .isNotEmpty &&
                                                              widget
                                                                      .main
                                                                      .user
                                                                      .id !=
                                                                  3)
                                                            Positioned(
                                                              bottom: widget.sy(
                                                                -8,
                                                              ),
                                                              right:
                                                                  widget.isMine
                                                                      ? widget
                                                                          .sx(2)
                                                                      : widget
                                                                          .sx(
                                                                            8,
                                                                          ),
                                                              child: BlocBuilder<
                                                                EmoteBloc,
                                                                EmoteState
                                                              >(
                                                                builder: (
                                                                  context,
                                                                  state,
                                                                ) {
                                                                  return ReactionTrigger(
                                                                    sx:
                                                                        widget
                                                                            .sx,
                                                                    sy:
                                                                        widget
                                                                            .sy,
                                                                    emote:
                                                                        state
                                                                            .emote,
                                                                    onSelected: (
                                                                      emoji,
                                                                    ) {
                                                                      sendEmote(
                                                                        widget
                                                                            .main
                                                                            .id,
                                                                        emoji,
                                                                      );
                                                                    },
                                                                    react:
                                                                        widget.main.reacts.isEmpty
                                                                            ? null
                                                                            : widget.main.reacts.last,
                                                                    main:
                                                                        widget
                                                                            .main,
                                                                    onEmojiSelected: (
                                                                      chat,
                                                                      emoji,
                                                                      position,
                                                                    ) {
                                                                      if (mounted) {
                                                                        _showSelectedEmojiEffect(
                                                                          context,
                                                                          emoji,
                                                                          position,
                                                                        );
                                                                        widget.onEmojiSelected?.call(
                                                                          chat,
                                                                          emoji,
                                                                        );
                                                                      }
                                                                    },
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      if (widget.main.type ==
                                                              ChatType.video ||
                                                          widget.main.type ==
                                                              ChatType
                                                                  .localFile ||
                                                          (widget.main.type ==
                                                                  ChatType
                                                                      .image &&
                                                              widget
                                                                      .main
                                                                      .user
                                                                      .id !=
                                                                  3))
                                                        Row(
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        widget
                                                                            .sx(
                                                                              8,
                                                                            ),
                                                                    vertical:
                                                                        widget
                                                                            .sy(
                                                                              4,
                                                                            ),
                                                                  ),
                                                              decoration: const BoxDecoration(
                                                                color:
                                                                    AppColors
                                                                        .white,
                                                                borderRadius:
                                                                    BorderRadius.all(
                                                                      Radius.circular(
                                                                        16,
                                                                      ),
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                _mainTime
                                                                    .shortHintDateWithTime2(
                                                                      context,
                                                                    ),
                                                                style: GoogleFonts.inter(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                        0.8,
                                                                      ),
                                                                  fontSize:
                                                                      widget.sy(
                                                                        12,
                                                                      ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      // SizedBox(
                                                      //     height: widget.sy(8)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (widget.main.loading ||
                                              widget.main.error)
                                            GestureDetector(
                                              onTap: _resend,
                                              child: Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: widget.sy(
                                                    widget.previous?.senderId ==
                                                                widget
                                                                    .main
                                                                    .senderId &&
                                                            widget
                                                                    .previous
                                                                    ?.type !=
                                                                ChatType.updated
                                                        ? 4
                                                        : 16,
                                                  ),
                                                ),
                                                child: Text(
                                                  widget.main.loading
                                                      ? ChattingLocalization.of(
                                                        context,
                                                      ).sending
                                                      : ChattingLocalization.of(
                                                        context,
                                                      ).tapToResend,
                                                  style: GoogleFonts.inter(
                                                    color:
                                                        widget.main.loading
                                                            ? Colors.black
                                                                .withOpacity(
                                                                  0.4,
                                                                )
                                                            : Colors.red,
                                                    fontSize: widget.sy(12),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        widget.main.user.id == 3
                            ? const Spacer()
                            : const SizedBox.shrink(),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildImageOrOther(BuildContext context, bool isMineImageSent) {
    final double maxWidth = MediaQuery.of(context).size.width * 0.8;
    final double maxHeight = widget.sy(600);

    Future<double> _getImageAspectRatio() async {
      try {
        if (widget.main.type == ChatType.image &&
            _isValidImageUrl(widget.main.href)) {
          final image = NetworkImage(widget.main.href);
          final completer = Completer<Size>();
          image
              .resolve(const ImageConfiguration())
              .addListener(
                ImageStreamListener(
                  (ImageInfo info, bool _) {
                    completer.complete(
                      Size(
                        info.image.width.toDouble(),
                        info.image.height.toDouble(),
                      ),
                    );
                  },
                  onError: (exception, stackTrace) {
                    completer.complete(const Size(16, 9)); // Mặc định nếu lỗi
                  },
                ),
              );
          final size = await completer.future;
          return size.width / size.height;
        } else if (widget.main.type == ChatType.localImage) {
          final image = FileImage(File(widget.main.href));
          final completer = Completer<Size>();
          image
              .resolve(const ImageConfiguration())
              .addListener(
                ImageStreamListener(
                  (ImageInfo info, bool _) {
                    completer.complete(
                      Size(
                        info.image.width.toDouble(),
                        info.image.height.toDouble(),
                      ),
                    );
                  },
                  onError: (exception, stackTrace) {
                    completer.complete(const Size(16, 9)); // Mặc định nếu lỗi
                  },
                ),
              );
          final size = await completer.future;
          return size.width / size.height;
        }
        return 16 / 9; // Tỉ lệ mặc định
      } catch (e) {
        return 16 / 9; // Tỉ lệ mặc định nếu có lỗi
      }
    }

    return FutureBuilder<double>(
      future: _getImageAspectRatio(),
      builder: (context, snapshot) {
        final aspectRatio =
            snapshot.data ?? 16 / 9; // Mặc định nếu chưa có dữ liệu
        if (widget.main.type == ChatType.image &&
            _isValidImageUrl(widget.main.href)) {
          return GestureDetector(
            onTap:
                widget.main.error
                    ? _resend
                    : (widget.main.href.isNotEmpty &&
                        !_imageError &&
                        !isMineImageSent)
                    ? _launchFile
                    : null,
            onLongPress:
                isMineImageSent
                    ? () => _showDeleteOnlyPopup(context, widget.sx, widget.sy)
                    : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.sy(8)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: CachedNetworkImage(
                    imageUrl: widget.main.href,
                    fit: BoxFit.cover,
                    progressIndicatorBuilder:
                        (context, url, progress) => Center(
                          child: CircularProgressIndicator(
                            value: progress.progress,
                            strokeWidth: 2,
                          ),
                        ),
                    errorWidget: _imageErrorNetworkBuilder,
                  ),
                ),
              ),
            ),
          );
        } else if (widget.main.type == ChatType.localImage) {
          return GestureDetector(
            onTap:
                widget.main.error
                    ? _resend
                    : (widget.main.href.isNotEmpty &&
                        !_imageError &&
                        !isMineImageSent)
                    ? _launchFile
                    : null,
            onLongPress:
                isMineImageSent
                    ? () => _showDeleteOnlyPopup(context, widget.sx, widget.sy)
                    : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.sy(8)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Image.file(
                    File(widget.main.href),
                    fit: BoxFit.fill,
                    cacheWidth:
                        (maxWidth * MediaQuery.of(context).devicePixelRatio)
                            .toInt(),
                    cacheHeight:
                        (maxHeight * MediaQuery.of(context).devicePixelRatio)
                            .toInt(),
                    errorBuilder: _imageErrorWidget,
                  ),
                ),
              ),
            ),
          );
        } else if (widget.main.type == ChatType.file ||
            widget.main.type == ChatType.video ||
            widget.main.type == ChatType.localFile ||
            widget.main.type == ChatType.localVideo) {
          return _renderFileField();
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    widget.main.content.isNotEmpty
                        ? ((widget.next?.senderId != widget.main.senderId ||
                                    _checkFirstDate) &&
                                !widget.isMine)
                            ? const EdgeInsets.all(0)
                            : const EdgeInsets.only(top: 0)
                        : const EdgeInsets.all(10),
                child: _buildMessageContent(context),
              ),
              if (widget.main.isEdited != 0)
                Padding(
                  padding: EdgeInsets.only(top: widget.sy(2)),
                  child: Text(
                    ChattingLocalization.of(context).edited,
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: widget.sy(10),
                    ),
                  ),
                ),
              widget.main.type == ChatType.video ||
                      widget.main.type == ChatType.image ||
                      widget.main.user.id == 3
                  ? const SizedBox.shrink()
                  : Padding(
                    padding: EdgeInsets.only(
                      top: widget.sy(4),
                      bottom: widget.sy(4),
                    ),
                    child: Text(
                      _mainTime.shortHintDateWithTime2(context),
                      style: GoogleFonts.inter(
                        color: Colors.black.withOpacity(0.8),
                        fontSize: widget.sx(12),
                      ),
                    ),
                  ),
            ],
          );
        }
      },
    );
  }

  Widget _buildContentPopup(BuildContext context, bool isImage) {
    if (isImage &&
        (widget.main.type == ChatType.image ||
            widget.main.type == ChatType.localImage)) {
      return Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 1,
              child:
                  widget.main.type == ChatType.image
                      ? Image.network(
                        widget.main.href,
                        fit: BoxFit.contain,
                        cacheWidth:
                            (MediaQuery.of(context).size.width *
                                    0.6 *
                                    MediaQuery.of(context).devicePixelRatio)
                                .toInt(),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          (loadingProgress.expectedTotalBytes ??
                                              1)
                                      : null,
                              strokeWidth: 2,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 40,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Không thể tải ảnh',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                      : Image.file(
                        File(widget.main.href),
                        fit: BoxFit.fill,
                        cacheWidth:
                            (widget.sx(300) *
                                    MediaQuery.of(context).devicePixelRatio)
                                .toInt(),
                        cacheHeight:
                            (widget.sy(450) *
                                    MediaQuery.of(context).devicePixelRatio)
                                .toInt(),
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 40,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Không thể tải ảnh cục bộ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
          ),
        ),
      );
    } else if (widget.main.type == ChatType.video ||
        widget.main.type == ChatType.localVideo ||
        widget.main.type == ChatType.localImage) {
      return Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  widget.main.thumb.isNotEmpty
                      ? (widget.main.type == ChatType.video
                          ? Image.network(
                            widget.main.thumb,
                            fit: BoxFit.contain,
                            cacheWidth:
                                (MediaQuery.of(context).size.width *
                                        0.6 *
                                        MediaQuery.of(context).devicePixelRatio)
                                    .toInt(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              (loadingProgress
                                                      .expectedTotalBytes ??
                                                  1)
                                          : null,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.videocam_off,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Không thể tải thumbnail video',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                          : Image.file(
                            File(widget.main.thumb),
                            fit: BoxFit.fill,
                            cacheWidth:
                                (widget.sx(300) *
                                        MediaQuery.of(context).devicePixelRatio)
                                    .toInt(),
                            cacheHeight:
                                (widget.sy(450) *
                                        MediaQuery.of(context).devicePixelRatio)
                                    .toInt(),
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.videocam_off,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Không thể tải thumbnail video cục bộ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ))
                      : Image.asset(
                        'assets/icons_message/video_placeholder.png',
                        fit: BoxFit.contain,
                      ),
                  Icon(
                    Icons.play_circle_filled,
                    size: widget.sy(50),
                    color: Colors.white.withOpacity(0.8),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return Column(
        crossAxisAlignment:
            widget.isMine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            padding:
                widget.main.content.isNotEmpty
                    ? ((widget.next?.senderId != widget.main.senderId ||
                                _checkFirstDate) &&
                            !widget.isMine)
                        ? const EdgeInsets.all(0)
                        : EdgeInsets.only(top: widget.sy(0))
                    : const EdgeInsets.all(10),
            child: _buildMessageContent(context),
          ),
          if (widget.main.isEdited != 0)
            Padding(
              padding: EdgeInsets.only(top: widget.sy(2)),
              child: Text(
                ChattingLocalization.of(context).edited,
                style: GoogleFonts.inter(
                  color: Colors.grey,
                  fontSize: widget.sy(10),
                ),
              ),
            ),
          widget.main.type == ChatType.video ||
                  widget.main.type == ChatType.localImage ||
                  widget.main.type == ChatType.localVideo ||
                  widget.main.type == ChatType.localFile ||
                  widget.main.type == ChatType.image ||
                  widget.main.user.id == 3 ||
                  widget.main.loading ||
                  widget.main.error
              ? const SizedBox.shrink()
              : Padding(
                padding: EdgeInsets.only(
                  top: widget.sy(4),
                  bottom: widget.sy(4),
                ),
              ),
        ],
      );
    }
  }

  void _showDeleteOnlyPopup(
    BuildContext context,
    Function(double) sx,
    Function(double) sy,
  ) async {
    if (mounted) {
      setState(() {
        _isSelected = true;
      });
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext dialogContext) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: sy(24), horizontal: sx(24)),
          child: SafeArea(
            child: Row(
              children: [
                PopupAction(
                  icon: Icons.delete_outline,
                  label: ChattingLocalization.of(context).delete,
                  color: Colors.red,
                  onTap: () {
                    _showPopupDelete(sx, sy);
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() {
        _isSelected = false;
      });
    }
  }

  Future<void> _showPopupDelete(Function(double) sy, Function(double) sx) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            ChattingLocalization.of(context).deleteMessage,
            style: TextStyle(fontSize: sy(20)),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    ChattingLocalization.of(context).cancelOnly,
                    style: const TextStyle(color: AppColors.mainRed),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _onDelete();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    ChattingLocalization.of(context).confirm,
                    style: const TextStyle(color: AppColors.mainRed),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String? extractFirstCodeLang(String markdown) {
    final RegExp codeLang = RegExp(r'^```(\w+)', multiLine: true);
    final match = codeLang.firstMatch(markdown);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  Widget _buildMessageContent(BuildContext context) {
    if (widget.main.content.isEmpty) {
      return Text(
        ChattingLocalization.of(context).noData,
        style: GoogleFonts.inter(
          color: Colors.black.withOpacity(0.6),
          fontSize: widget.sy(12),
        ),
      );
    }

    String content = widget.main.content
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<b>(.*?)</b>', caseSensitive: false), '**\$1**')
        .replaceAll(RegExp(r'<i>(.*?)</i>', caseSensitive: false), '_\$1_')
        .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), '');

    final bool hasCodeBlock =
        RegExp(
          r'```[\s\S]*?```|\*{1,2}.*?\*{1,2}|`.*?`',
          multiLine: true,
        ).hasMatch(content) ||
        extractFirstCodeLang(content) != null;

    // Nếu là tin nhắn từ user.id == 3 và có code block, ưu tiên sử dụng ExpandableMarkdown với chiều ngang 0.85
    if (widget.main.user.id == 3 && hasCodeBlock) {
      return Wrap(
        children: [
          SizedBox(
            width: double.infinity,
            child: ExpandableMarkdown(
              time: widget.main.createdAtFormat,
              markdownContent: content,
              sy: widget.sy,
              sx: widget.sx,
            ),
          ),
        ],
      );
    }

    // Xử lý tin nhắn HTML
    // Đừng bỏ đoạn comment bên dưới
    // if (widget.main.content.isHtml) {
    //   return Wrap(
    //     children: [
    //       ConstrainedBox(
    //         constraints: BoxConstraints(
    //             maxWidth: MediaQuery.of(context).size.width * 0.85,
    //             minWidth: 0),
    //         child: widget.main.user.id == 3 && hasCodeBlock
    //             ? ExpandableMarkdown(
    //                 time: widget.main.createdAtFormat,
    //                 markdownContent: content,
    //                 sy: widget.sy,
    //                 sx: widget.sx,
    //               )
    //             : ExpandableHtml(
    //                 key: ValueKey(widget.main.id),
    //                 htmlContent: widget.main.content,
    //                 maxHeight: widget.sy(230),
    //                 sy: widget.sy,
    //                 sx: widget.sx,
    //               ),
    //       ),
    //     ],
    //   );
    // }

    // Xử lý tin nhắn văn bản với mentions và URLs
    final RegExp pattern = RegExp(
      r'(https?:\/\/[^\s]+)|(@[\w]+)',
      caseSensitive: false,
    );
    final List<TextSpan> textSpans = [];
    int lastIndex = 0;

    final users = widget.users;
    if (users.isEmpty) {
      debugPrint(
        'Danh sách users rỗng trong InternalChatItem: ${widget.main.id}',
      );
    }

    for (final match in pattern.allMatches(content)) {
      if (match.start > lastIndex) {
        textSpans.add(
          TextSpan(
            text: content.substring(lastIndex, match.start),
            style: GoogleFonts.inter(
              color: Colors.black,
              fontSize: content.isNotEmpty ? widget.sy(17) : widget.sy(12),
            ),
          ),
        );
      }

      final matchText = match.group(0)!;

      if (matchText.startsWith('@')) {
        final username = matchText.substring(1);
        final user = users.firstWhere(
          (u) => u.username.toLowerCase() == username.toLowerCase(),
          orElse:
              () => const ChatUserSuggested(
                id: -1,
                username: '',
                name: '',
                avatar: '',
              ),
        );

        textSpans.add(
          TextSpan(
            text: matchText,
            style: GoogleFonts.inter(
              color: Colors.blue,
              fontSize: widget.sy(17),
              fontWeight: FontWeight.w500,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () {
                    if (user.id != -1) {
                      widget.onUsernameTap(username);
                    }
                  },
          ),
        );
      } else {
        textSpans.add(
          TextSpan(
            text: matchText,
            style: GoogleFonts.inter(
              color: Colors.blue,
              fontSize: widget.sy(17),
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () {
                    _tapUrl(matchText);
                  },
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      textSpans.add(
        TextSpan(
          text: content.substring(lastIndex),
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: content.isNotEmpty ? widget.sy(17) : widget.sy(12),
          ),
        ),
      );
    }
    final maxHeight = widget.sy(
      widget.main.user.fullName == 'System' ? 20 : 225,
    );
    return Wrap(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                Platform.isMacOS || Platform.isWindows
                    ? MediaQuery.of(context).size.width / 3
                    : MediaQuery.of(context).size.width * 0.85,
            minWidth: 0,
          ),
          child:
              widget.main.user.id == 3
                  ? ExpandableHtmlSystem(
                    time: widget.main.createdAtFormat,
                    key: ValueKey(widget.main.id),
                    htmlContent: content,
                    maxHeight: widget.sy(20),
                    sy: widget.sy,
                    sx: widget.sx,
                  )
                  : ExpandableText(
                    textSpans: textSpans,
                    maxHeight: maxHeight,
                    sy: widget.sy,
                  ),
        ),
      ],
    );
  }

  Widget _renderFileField() {
    final double maxWidth = widget.sx(300); // Kích thước tối đa
    final double maxHeight = widget.sy(500); // Chiều cao tối đa
    const double defaultAspectRatio = 16 / 9; // Tỉ lệ mặc định cho video

    if (widget.main.type == ChatType.video ||
        widget.main.type == ChatType.localVideo) {
      return GestureDetector(
        onTap:
            widget.main.error
                ? _resend
                : (widget.main.href.isNotEmpty ? _launchFile : null),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.sy(8)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: AspectRatio(
              aspectRatio:
                  defaultAspectRatio, // Có thể thay bằng logic lấy tỉ lệ động nếu cần
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.main.thumb.isNotEmpty
                      ? (widget.main.type == ChatType.video
                          ? CachedNetworkImage(
                            imageUrl: widget.main.thumb,
                            fit: BoxFit.fill, // Lấp đầy container
                            placeholder:
                                (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) =>
                                    _imageErrorWidget(context, error, null),
                          )
                          : Image.file(
                            File(widget.main.thumb),
                            fit: BoxFit.fill, // Lấp đầy container
                            cacheWidth:
                                (maxWidth *
                                        MediaQuery.of(context).devicePixelRatio)
                                    .toInt(),
                            cacheHeight:
                                (maxHeight *
                                        MediaQuery.of(context).devicePixelRatio)
                                    .toInt(),
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    _imageErrorWidget(
                                      context,
                                      error,
                                      stackTrace,
                                    ),
                          ))
                      : Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(widget.sy(8)),
                        ),
                        child: Icon(
                          Icons.videocam_off,
                          size: widget.sy(50),
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ),
                  Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: widget.sy(50),
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Phần xử lý file không đổi
    late final Widget iconWidget;
    const double iconSize = 35;

    Widget buildImageIcon(String path) {
      return Image.asset(
        path,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
    }

    switch (widget.main.fileName.extension.toLowerCase()) {
      case 'word':
        iconWidget = buildImageIcon('assets/icons_message/word.png');
        break;
      case 'excel':
        iconWidget = buildImageIcon('assets/icons_message/excel.png');
        break;
      case 'apk':
        iconWidget = buildImageIcon('assets/icons_message/apk.png');
        break;
      case 'zip':
        iconWidget = buildImageIcon('assets/icons_message/zip.png');
        break;
      case 'pdf':
        iconWidget = buildImageIcon('assets/icons_message/pdf.png');
        break;
      case 'ipa':
        iconWidget = buildImageIcon('assets/icons_message/ipa.png');
        break;
      case 'powerpoint':
        iconWidget = buildImageIcon('assets/icons_message/powerpoint.png');
        break;
      case 'mp4':
        iconWidget = buildImageIcon('assets/icons_message/mp4.png');
        break;
      default:
        iconWidget = Icon(
          widget.main.type == ChatType.video ||
                  widget.main.type == ChatType.localVideo
              ? Icons.play_arrow_rounded
              : Icons.file_download_rounded,
          size: iconSize,
          color: Colors.black.withOpacity(0.3),
        );
        break;
    }

    return GestureDetector(
      onTap:
          widget.main.error
              ? _resend
              : (widget.main.href.isNotEmpty ? _launchFile : null),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(children: [iconWidget]),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.main.fileName.basename.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.5,
                  ),
                  child: Text(
                    widget.main.fileName.basename,
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: widget.sy(16),
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Text(
                widget.main.size,
                style: GoogleFonts.inter(
                  color: Colors.black.withOpacity(0.5),
                  fontSize: widget.sy(14),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                ModuleLocalization.of(context).clickToDownload,
                style: GoogleFonts.inter(
                  color: Colors.black.withOpacity(0.5),
                  fontSize: widget.sy(16),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showReactionPopup({
    required BuildContext context,
    required GlobalKey targetKey,
    required ChatDetail item,
    required bool isMine,
    required MyEmote emotes,
    void Function(String emoji)? onReact,
    void Function()? onRemove,
    void Function()? onForward,
  }) {
    if (_reactionOverlay != null) {
      _reactionOverlay?.remove();
      _reactionOverlay = null;
    }

    final renderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    const popupWidth = 300.0;
    const popupHeight = 220.0;
    const margin = 8.0;

    double offsetX = -(popupWidth / 2) + size.width / 2;
    if (position.dx + offsetX < margin) {
      offsetX = -position.dx + margin;
    } else if (position.dx + popupWidth + offsetX > screenWidth - margin) {
      offsetX = screenWidth - popupWidth - position.dx - margin;
    }

    double top;
    if (item.type == ChatType.image || item.type == ChatType.localImage) {
      top = (screenHeight - popupHeight) / 5;
    } else if (position.dy > screenHeight * 0.25 &&
        position.dy < screenHeight * 0.75) {
      top = (screenHeight - popupHeight) / 3;
    } else if (position.dy + size.height + popupHeight >
        screenHeight - margin) {
      top = position.dy - popupHeight - margin;
    } else {
      top = (screenHeight - popupHeight) / 6;
    }

    final controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );

    final scaleAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutBack,
    );

    final fadeAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeIn,
    );

    _reactionOverlay = OverlayEntry(
      builder:
          (_) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              _reactionOverlay?.remove();
              _reactionOverlay = null;
              controller.dispose();
            },
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.6),
                ),
                Positioned(
                  top: top,
                  left: position.dx + offsetX,
                  width: popupWidth,
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: _buildPopup(
                            item: item,
                            emotes: emotes,
                            onReact: (emoji) async {
                              final response = await sendEmote(item.id, emoji);
                              _reactionOverlay?.remove();
                              _reactionOverlay = null;
                              controller.dispose();
                              onReact?.call(emoji);
                              if (mounted && response.success == true) {
                                widget.onEmojiSelected?.call(
                                  widget.main,
                                  emoji,
                                );
                              } else {
                                MyToast.show(
                                  response.errors.toString(),
                                  type: MyToastType.fail,
                                  durationType: MyToastDurationType.short,
                                );
                              }
                            },
                            onRemove: () {
                              _reactionOverlay?.remove();
                              _reactionOverlay = null;
                              controller.dispose();
                              onRemove?.call();
                            },
                            onForward: () {
                              _reactionOverlay?.remove();
                              _reactionOverlay = null;
                              controller.dispose();
                              onForward?.call();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );

    if (mounted) {
      Overlay.of(context).insert(_reactionOverlay!);
      controller.forward();
    }
  }

  Widget _buildPopup({
    required ChatDetail item,
    required MyEmote emotes,
    void Function(String emoji)? onReact,
    void Function()? onRemove,
    void Function()? onForward,
  }) {
    final emoteList = emotes.data.entries.toList();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 1,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.main.user.fullName,
                    style: GoogleFonts.inter(
                      color:
                          Platform.isAndroid || Platform.isIOS
                              ? const Color(0xFFC35D18)
                              : Colors.black.withOpacity(0.8),
                      fontSize: widget.sy(13),
                    ),
                  ),
                  _buildContentPopup(
                    context,
                    item.type == ChatType.image ||
                        item.type == ChatType.localImage,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _mainTime.shortHintDateWithTime2(context),
                        style: GoogleFonts.inter(
                          color: Colors.black.withOpacity(0.8),
                          fontSize: widget.sy(12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    emoteList.map((e) {
                      return GestureDetector(
                        onTap: () {
                          onReact?.call(e.key);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            e.value,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _verticalActionButton(
                    'assets/chat_icons/chat_replie.png',
                    ChattingLocalization.of(context).reply,
                    () {
                      widget.onReply(widget.main);
                      onRemove?.call();
                    },
                  ),
                  _verticalActionButton(
                    'assets/chat_icons/chat_forward.png',
                    ChattingLocalization.of(context).forward,
                    () {
                      onForward?.call();
                    },
                  ),
                  _verticalActionButton(
                    'assets/chat_icons/chat_copy.png',
                    ChattingLocalization.of(context).copy,
                    () {
                      _copyToClipboard();
                      onRemove?.call();
                    },
                  ),
                  _verticalActionButton(
                    'assets/chat_icons/chat_pined.png',
                    ChattingLocalization.of(context).pin,
                    () {
                      final pinState = context.read<PinChatBloc>().state;
                      bool isPinned =
                          pinState is PinListLoaded &&
                          pinState.pinList.data.any(
                            (pin) => pin.internalChatId == widget.main.id,
                          );
                      isPinned ? _onUnPin() : _onPin();
                      onRemove?.call();
                    },
                  ),
                  if (widget.isMine == true)
                    _verticalActionButton(
                      'assets/chat_icons/chat_edit.png',
                      ChattingLocalization.of(context).edit,
                      () {
                        widget.onEdit?.call(
                          widget.main.id,
                          parse(widget.main.content).documentElement!.text,
                        );
                        onRemove?.call();
                      },
                    ),
                  _verticalActionButton(
                    'assets/chat_icons/chat_replie_splash.png',
                    ChattingLocalization.of(context).quickReply,
                    () {
                      onRemove?.call();
                    },
                  ),
                  _verticalActionButton(
                    'assets/chat_icons/chat_info.png',
                    ChattingLocalization.of(context).detail,
                    () {
                      onRemove?.call();
                    },
                  ),
                  if (widget.isMine == true)
                    _verticalActionButton(
                      'assets/chat_icons/chat_delete.png',
                      ChattingLocalization.of(context).delete,
                      () {
                        _onDelete();
                        onRemove?.call();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 200),
          ],
        ),
      ),
    );
  }

  Widget _verticalActionButton(
    String iconPath,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(iconPath, width: 30, height: 30, fit: BoxFit.contain),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDelete() async {
    final response = await RepositoryProvider.of<InternalChatRepository>(
      context,
    ).detailChatDelete(internalChatDetailId: widget.main.id);
    if (response.success == true) {
      debugPrint('Delete success: ${widget.main.id}');
      widget.onDelete?.call(widget.main.id);
    } else {
      MyToast.show(
        response.message,
        type: MyToastType.fail,
        durationType: MyToastDurationType.short,
      );
    }
  }

  void _onPin() {
    BlocProvider.of<PinChatBloc>(context).add(
      AddPinChatEvent(
        internalChatId: widget.main.internalChatId,
        internalChatDetailId: widget.main.id,
      ),
    );
  }

  void _onUnPin() {
    BlocProvider.of<PinChatBloc>(context).add(
      RemovePinChatEvent(
        internalChatId: widget.main.internalChatId,
        internalChatDetailId: widget.main.id,
      ),
    );
  }

  Widget _imageErrorWidget(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    if (!_imageError && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _imageError = true;
          });
        }
      });
    }
    return SizedBox(
      width: widget.sx(400),
      height: widget.sy(500),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: widget.sy(40),
              color: Colors.red,
            ),
            SizedBox(height: widget.sy(4)),
            Text(
              ChattingLocalization.of(context).cannotLoadImage,
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: widget.sy(14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageErrorNetworkBuilder(
    BuildContext context,
    String url,
    Object error,
  ) {
    if (!_imageError && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _imageError = true;
          });
        }
      });
    }
    return SizedBox(
      width: widget.sx(400),
      height: widget.sy(500),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: widget.sy(40),
              color: Colors.red,
            ),
            SizedBox(height: widget.sy(4)),
            Text(
              ChattingLocalization.of(context).cannotLoadImage,
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: widget.sy(14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _listener(BuildContext context, AppState state) {
    if (state is ChatShownDate) {
      if (state.chat == widget.main &&
          widget.previous?.senderId == widget.main.senderId) {
        if (mounted) {
          setState(() {
            _previousShownDate = state.show;
          });
        }
      }
    }
  }

  void _launchFile() async {
    if (widget.main.type == ChatType.image ||
        widget.main.type == ChatType.localImage) {
      if (!_imageError && widget.main.href.isNotEmpty) {
        final chatState = BlocProvider.of<InternalChatBloc>(context).state;
        final conversationId = widget.main.internalChatId.toString();
        final imageList =
            chatState.chatDetailCache[conversationId]
                ?.where(
                  (msg) =>
                      (msg.type == ChatType.image ||
                          msg.type == ChatType.localImage) &&
                      msg.href.isNotEmpty,
                )
                .toList() ??
            [];
        final imageIndex = imageList.indexWhere(
          (img) => img.id == widget.main.id,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => MultiImageView(
                  urls:
                      imageIndex != -1
                          ? imageList.map((img) => img.href).toList()
                          : [widget.main.href],
                  type:
                      widget.main.type == ChatType.localImage
                          ? ImageViewType.file
                          : ImageViewType.network,
                  initialPage: imageIndex != -1 ? imageIndex : 0,
                ),
          ),
        );
      } else {
        MyToast.show(
          ChattingLocalization.of(context).cannotLoadImage,
          type: MyToastType.fail,
        );
      }
    } else if (widget.main.type == ChatType.video ||
        widget.main.type == ChatType.localVideo) {
      if (widget.main.href.isNotEmpty) {
        Offset position = (_contentKey.currentContext?.findRenderObject()
                as RenderBox)
            .localToGlobal(Offset.zero);
        Navigator.of(NavigationKeys.mainNavState.currentContext!).push(
          PageTransition(
            page: Video(url: widget.main.href),
            type: PageTransitionType.position,
            begin: RelativeRect.fromSize(
              Rect.fromLTWH(
                position.dx,
                position.dy,
                _contentKey.currentContext?.size?.width ?? 0,
                _contentKey.currentContext?.size?.height ?? 0,
              ),
              MediaQuery.of(context).size,
            ),
            end: RelativeRect.fromSize(
              Rect.fromLTWH(
                0,
                0,
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
              ),
              MediaQuery.of(context).size,
            ),
          ),
        );
      }
    } else {
      if (widget.main.href.isNotEmpty) {
        Uri url = Uri.parse(widget.main.href);
        await launchUrl(url);
      }
    }
  }

  Widget _imageErrorResponse(BuildContext context, String url, Object error) {
    return Container();
  }

  void _onShowDate() {
    if (mounted) {
      setState(() {
        _dateShow = !_dateShow;
      });
    }
    if (widget.next != null) {
      BlocProvider.of<AppBloc>(
        context,
      ).add(AppEvent.showChatDate(widget.next!, _dateShow));
    }
  }

  void _copyToClipboard() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: parse(widget.main.content).documentElement!.text),
      );
      MyToast.show(
        ChattingLocalization.of(
          NavigationKeys.mainNavState.currentContext!,
        ).copiedMessage,
        type: MyToastType.fail,
        icon: Icon(
          Icons.copy,
          size: widget.sy(24),
          color: Colors.black.withOpacity(0.2),
        ),
      );
    } catch (_) {
      MyToast.show(
        ChattingLocalization.of(
          NavigationKeys.mainNavState.currentContext!,
        ).cannotCopyMessage,
        type: MyToastType.fail,
      );
    }
  }

  void _resend() {
    print('Resending chat: ${widget.main.id}');
    widget.onResend?.call(widget.main);
  }

  FutureOr<bool> _tapUrl(String link) async {
    Uri url = Uri.parse(link);
    return await launchUrl(url);
  }

  Widget _buildImageLoading(
    BuildContext context,
    String url,
    DownloadProgress progress,
  ) {
    Widget render =
        _imageLoaded
            ? Container()
            : ShimmerImageCard(
              baseColor: Colors.grey[200]!, // Xám nhạt
              highlightColor: Colors.white,
              sy: widget.sy,
              sx: widget.sx,
              margin: EdgeInsets.zero,
              borderRadius: widget.sy(8),
              aspectRatio: 1.77, // 16/9 cho hình ngang, điều chỉnh nếu cần
            );
    _imageLoaded = true;
    return render;
  }

  void _goToUserDetail() {
    Navigator.of(context).push(
      PageTransition(
        page: UserDetail(
          idUser: widget.main.user.id,
          fullName: widget.main.user.fullName,
          username: widget.main.user.username,
          avatar: widget.main.user.avatar,
          tag: widget.main.hashCode,
        ),
        type: PageTransitionType.slideToLeft,
      ),
    );
  }
}

Widget _reactionIcon(String emoji) {
  return GestureDetector(
    onTap: () {
      debugPrint("Reacted with $emoji");
    },
    child: Text(emoji, style: const TextStyle(fontSize: 15)),
  );
}
/*
MultiImageView
showReactionPopup
*/