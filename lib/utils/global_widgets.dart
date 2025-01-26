import 'package:flutter/material.dart';

class GlobalWidgets {
  BuildContext context;

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  GlobalWidgets(this.context);

  // Displays SnackBar to user, lasting two seconds
  void showSnackBar(
      {required String content,
      Color? backgroundColor,
      Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(content),
      duration: duration,
      backgroundColor: backgroundColor ?? Colors.black,
    ));
  }
}
