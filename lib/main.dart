import 'package:fbla_application/api/firebase_auth_config.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:fbla_application/screens/create_class.dart';
import 'package:fbla_application/screens/first_time_sign_in.dart';
import 'package:fbla_application/screens/home_screen.dart';
import 'package:fbla_application/screens/join_class.dart';
import 'package:fbla_application/screens/profile_screen.dart';
import 'package:fbla_application/utils/auth_screens.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/utils/global_widgets.dart';
import 'package:fbla_application/utils/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
      title: Constants.appName,
      initialRoute: (FirebaseAuth.instance.currentUser == null)
          ? Constants.signInRoute
          : Constants.homeRoute,
      routes: _buildAppRoutes(),
      theme: AppTheme().mainTheme,
      darkTheme: AppTheme().darkTheme,
      themeMode: ThemeMode.light,
      navigatorKey: GlobalWidgets.navigatorKey,
    );
  }

  Map<String, WidgetBuilder> _buildAppRoutes() {
    return {
      Constants.signInRoute: (context) =>
          AuthScreens.buildSignInScreen(context),
      Constants.homeRoute: (context) => const Home(),
      Constants.profileRoute: (context) => ProfileScreen(),
      Constants.firstTimeSignInRoute: (context) => FirstTimeSignIn(),
      Constants.createClassRoute: (context) => CreateClassScreen(),
      Constants.joinClassRoute: (context) => JoinClassScreen(),
      Constants.classHomeRoute: (context) => ClassHome(),
    };
  }
}
