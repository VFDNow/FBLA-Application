import 'package:fbla_application/api/firebase_auth_config.dart';
import 'package:fbla_application/screens/home_screen.dart';
import 'package:fbla_application/utils/auth_screens.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // Ensure firebase initialized before booting app
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configures sign in providers
  FirebaseAuthConfig.configureProviders();

  runApp(const FBLAApp());
}

class FBLAApp extends StatelessWidget {
  const FBLAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        initialRoute: Constants.signInRoute, routes: _buildAppRoutes());
  }

  Map<String, WidgetBuilder> _buildAppRoutes() {
    return {
      Constants.signInRoute: (context) =>
          AuthScreens.buildSignInScreen(context),
      Constants.homeRoute: (context) => const Home(),
      Constants.profileRoute: (context) => AuthScreens.buildProfileScreen(context),
    };
  }
}