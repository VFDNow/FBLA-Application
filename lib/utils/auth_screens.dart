import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/utils/global_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';

class AuthScreens {
  static Widget buildSignInScreen(BuildContext context) {
    return SignInScreen(
      providers: FirebaseUIAuth.providersFor(FirebaseAuth.instance.app),
      actions: [
        _handleUserCreation(),
        _handleSignIn(context),
      ],
    );
  }

  // Handle User Creation
  static AuthStateChangeAction<UserCreated> _handleUserCreation() {
    return AuthStateChangeAction<UserCreated>((context, state) {
      Navigator.pushReplacementNamed(context, Constants.signInRoute);

      GlobalWidgets(context).showSnackBar(
          content: "User Created Succesfully!\nPlease Sign In.",
          backgroundColor: Colors.green);
    });
  }

  static AuthStateChangeAction<SignedIn> _handleSignIn(BuildContext context) {
    return AuthStateChangeAction<SignedIn>((context, state) {
      Navigator.pushReplacementNamed(context, Constants.profileRoute);
    });
  }
}
