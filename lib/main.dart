import 'package:fbla_application/api/firebase_auth_config.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:fbla_application/screens/create_class.dart';
import 'package:fbla_application/screens/first_time_sign_in.dart';
import 'package:fbla_application/screens/quiz_creation_screen.dart';
import 'package:fbla_application/screens/teacher_home_screen.dart';
import 'package:fbla_application/screens/home_screen.dart';
import 'package:fbla_application/screens/join_class.dart';
import 'package:fbla_application/screens/profile_screen.dart';
import 'package:fbla_application/screens/quiz_screen.dart';
import 'package:fbla_application/utils/auth_screens.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/utils/global_widgets.dart';
import 'package:fbla_application/utils/theme.dart';
import 'package:fbla_application/widgets/quiz_ui/quiz_results_screen.dart';
import 'package:fbla_application/widgets/themed_status_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:fbla_application/screens/teacher_class_home_screen.dart';
import 'package:fbla_application/screens/teacher_section_manage_screen.dart';

void main() async {
  // Ensure firebase initialized before booting app
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    name: defaultTargetPlatform == TargetPlatform.android ? 'FBLA' : null,
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
      onGenerateRoute: (settings) {
        // Handle routes that need arguments
        if (settings.name == Constants.teacherSectionManageRoute) {
          return MaterialPageRoute(
            builder: (context) => TeacherSectionManageScreen(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }

  Map<String, WidgetBuilder> _buildAppRoutes() {
    return {
      Constants.signInRoute: (context) =>
          ThemedStatusBar(child: AuthScreens.buildSignInScreen(context)),
      Constants.homeRoute: (context) => const ThemedStatusBar(child: Home()),
      Constants.profileRoute: (context) => ThemedStatusBar(child: ProfileScreen()),
      Constants.firstTimeSignInRoute: (context) => ThemedStatusBar(child: FirstTimeSignIn()),
      Constants.createClassRoute: (context) => ThemedStatusBar(child: CreateClassScreen()),
      Constants.joinClassRoute: (context) => ThemedStatusBar(child: JoinClassScreen()),
      Constants.classHomeRoute: (context) => ThemedStatusBar(child: ClassHome()),
      Constants.quizRoute: (context) => ThemedStatusBar(child: QuizScreen()),
      Constants.quizResultsRoute: (context) => ThemedStatusBar(child: QuizResultsScreen()),
      Constants.teacherHomeRoute: (context) => ThemedStatusBar(child: TeacherHomeScreen()),
      Constants.teacherClassHomeRoute: (context) => ThemedStatusBar(child: TeacherClassHomeScreen()),
      Constants.quizCreationRoute: (context) => const ThemedStatusBar(child: QuizCreationScreen()), 
    };
  }
}
