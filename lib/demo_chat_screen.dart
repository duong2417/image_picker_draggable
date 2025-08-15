import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:image_picker_with_draggable/internal.dart';
import 'package:image_picker_with_draggable/simple_chat_item.dart';

// Mock data classes based on usage in InternalChatItem
class ChatDetail {
  final int id;
  final String content;
  final String href;
  final int createdAtTimestamp;
  final int senderId;
  final ChatUser user;
  final ChatType type;
  final bool loading;
  final bool error;
  final ChatDetail? quoted;

  ChatDetail({
    required this.id,
    this.content = '',
    this.href = '',
    required this.createdAtTimestamp,
    required this.senderId,
    required this.user,
    required this.type,
    this.loading = false,
    this.error = false,
    this.quoted,
  });
}

class ChatUser {
  final int id;
  final String fullName;
  final String avatar;

  ChatUser({required this.id, required this.fullName, required this.avatar});
}

class ChatUserSuggested {
  // Mock class
}

enum ChatType { text, image, localImage, video, file, updated }

// Mock Blocs
class EmoteState {
  final List<String> emote;
  EmoteState({this.emote = const []});
}

class EmoteBloc extends Cubit<EmoteState> {
  EmoteBloc() : super(EmoteState());
}

class AppState {}

class AppBloc extends Cubit<AppState> {
  AppBloc() : super(AppState());
}

class DemoChatScreen extends StatefulWidget {
  const DemoChatScreen({super.key});

  @override
  State<DemoChatScreen> createState() => _DemoChatScreenState();
}

class _DemoChatScreenState extends State<DemoChatScreen> {
  final List<ChatDetail> _messages = [];

  @override
  void initState() {
    super.initState();
    _generateMockMessages();
  }

  void _generateMockMessages() {
    final user1 = ChatUser(
      id: 1,
      fullName: "John Doe",
      avatar: "https://i.pravatar.cc/150?u=a042581f4e29026704d",
    );
    final user2 = ChatUser(
      id: 2,
      fullName: "Jane Smith",
      avatar: "https://i.pravatar.cc/150?u=a042581f4e29026704e",
    );
    final systemUser = ChatUser(id: 3, fullName: "System", avatar: "");

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    setState(() {
      _messages.addAll([
        ChatDetail(
          id: 1,
          content: "Hello there!",
          createdAtTimestamp: yesterday.millisecondsSinceEpoch ~/ 1000,
          senderId: 1,
          user: user1,
          type: ChatType.text,
        ),
        ChatDetail(
          id: 2,
          content: "Hi! How are you?",
          createdAtTimestamp:
              now
                  .subtract(const Duration(minutes: 35))
                  .millisecondsSinceEpoch ~/
              1000,
          senderId: 2,
          user: user2,
          type: ChatType.text,
        ),
        ChatDetail(
          id: 3,
          content: "I'm good, thanks! Check out this image.",
          createdAtTimestamp:
              now
                  .subtract(const Duration(minutes: 30))
                  .millisecondsSinceEpoch ~/
              1000,
          senderId: 1,
          user: user1,
          type: ChatType.text,
        ),
        ChatDetail(
          id: 4,
          href: "https://picsum.photos/seed/picsum/400/300",
          createdAtTimestamp:
              now
                  .subtract(const Duration(minutes: 29))
                  .millisecondsSinceEpoch ~/
              1000,
          senderId: 1,
          user: user1,
          type: ChatType.image,
        ),
        ChatDetail(
          id: 5,
          content: "Wow, nice picture!",
          createdAtTimestamp:
              now
                  .subtract(const Duration(minutes: 25))
                  .millisecondsSinceEpoch ~/
              1000,
          senderId: 2,
          user: user2,
          type: ChatType.text,
        ),
        ChatDetail(
          id: 6,
          content: "This is a message from the system user.",
          createdAtTimestamp:
              now
                  .subtract(const Duration(minutes: 20))
                  .millisecondsSinceEpoch ~/
              1000,
          senderId: 3,
          user: systemUser,
          type: ChatType.text,
        ),
        ChatDetail(
          id: 7,
          content: "This is a reply to your image.",
          createdAtTimestamp:
              now
                  .subtract(const Duration(minutes: 15))
                  .millisecondsSinceEpoch ~/
              1000,
          senderId: 2,
          user: user2,
          type: ChatType.text,
          quoted: ChatDetail(
            id: 4,
            href: "https://picsum.photos/seed/picsum/400/300",
            createdAtTimestamp:
                now
                    .subtract(const Duration(minutes: 29))
                    .millisecondsSinceEpoch ~/
                1000,
            senderId: 1,
            user: user1,
            type: ChatType.image,
          ),
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Simple responsive scaling functions
    double sy(double value) =>
        value * (MediaQuery.of(context).size.height / 812.0);
    double sx(double value) =>
        value * (MediaQuery.of(context).size.width / 375.0);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EmoteBloc()),
        BlocProvider(create: (_) => AppBloc()),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text("Chat Demo")),
        body: ListView.builder(
          itemCount: _messages.length,
          padding: const EdgeInsets.all(8.0),
          itemBuilder: (context, index) {
            final message = _messages[index];
            final previousMessage = index > 0 ? _messages[index - 1] : null;
            final nextMessage =
                index < _messages.length - 1 ? _messages[index + 1] : null;
            // Assuming user with id 2 is "me"
            final isMine = message.senderId == 2;
            return SimpleChatItem(message: message, isMine: isMine);
            // return InternalChatItem(
            //   main: message,
            //   previous: previousMessage,
            //   next: nextMessage,
            //   isMine: isMine,
            //   sy: sy,
            //   sx: sx,
            //   onReply: (chat) => print("Replying to: ${chat}"),
            //   onUsernameTap: (username) => print("Tapped on: $username"),
            //   users: const [],
            // );
          },
        ),
      ),
    );
  }
}
