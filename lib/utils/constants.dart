import 'package:flutter/material.dart';

class Constants {
  // App Info
  static const String appName = "FBLA App";

  // Routes
  static const String homeRoute = "/home";
  static const String signInRoute = "/sign-in";
  static const String firstTimeSignInRoute = "/first-time-sign-in";
  static const String profileRoute = "/profile";
  static const String landingRoute = "/landing";
  static const String createClassRoute = "/create-class";
  static const String joinClassRoute = "/join-class";
  static const String classHomeRoute = "/class-home";
  static const String quizRoute = "/quiz";
  static const String quizResultsRoute = "/quiz-results";

  // External API Routes
  static const String profilePictureRoute =
      "https://api.dicebear.com/9.x/miniavs/png?seed=";

  static const List<Color> quizColors = [
    Color(0xFFE57373),
    Color(0xFF81C784),
    Color(0xFF64B5F6),
    Color(0xFFFFD54F),
    Color(0xFF9575CD),
    Color(0xFF4DB6AC),
    Color(0xFFA1887F),
    Color(0xFF90A4AE),
  ];

  // Icon String Map
  static const Map<String, IconData> subjectIconStringMap = {
    "General": Icons.school,
    "Science": Icons.science,
    "Math": Icons.calculate,
    "Gym": Icons.fitness_center,
    "English": Icons.book,
    "History": Icons.hourglass_empty,
    "Art": Icons.palette,
    "Music": Icons.music_note,
    "Computer Science": Icons.computer,
    "Language": Icons.language,
  };

  static const Map<String, IconData> questionIconStringMap = {
    "star": Icons.star,
    "dash": Icons.dashboard,
    "token": Icons.token,
    "bold": Icons.bolt,
    "clean": Icons.clean_hands,
    "cookie": Icons.cookie,
    "cake": Icons.cake,
    "computer": Icons.computer,
    "person": Icons.person,
    "flutter": Icons.flutter_dash,
    "check": Icons.check,
    "x": Icons.close,
  };
}
