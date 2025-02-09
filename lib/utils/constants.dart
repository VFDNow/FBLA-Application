import 'package:flutter/material.dart';

class Constants {
  // App Info
  static const String appName = "FBLA App";

  // Routes
  static const String homeRoute = "/home";
  static const String signInRoute = "/home/sign-in";
  static const String firstTimeSignInRoute = "/first-time-sign-in";
  static const String profileRoute = "/profile";
  static const String landingRoute = "/landing";
  static const String createClassRoute = "/create-class";
  static const String joinClassRoute = "/join-class";

  // External API Routes
  static const String profilePictureRoute =
      "https://api.dicebear.com/9.x/miniavs/png?seed=";

  // Icon String Map
  static const Map<String, IconData> iconStringMap = {
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
}
