import 'package:flutter/material.dart';
import 'home.dart';

BuildContext? get globalAppContext => navigatorKey.currentContext;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Keyboard Height Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomeView(),
    );
  }
}
