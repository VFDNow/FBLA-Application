import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/utils/global_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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
      
      // If google sign in, skip re-log and go straight to profile.
      if (FirebaseAuth.instance.currentUser?.providerData[0].providerId == "google.com") {
        Navigator.pushReplacementNamed(context, Constants.profileRoute);

        GlobalWidgets(context).showSnackBar(
          content: "User Created Succesfully!",
          backgroundColor: Colors.green);
        
        return;
      }

      Navigator.pushReplacementNamed(context, Constants.signInRoute);

      GlobalWidgets(context).showSnackBar(
          content: "User Created Succesfully!\nPlease Sign In.",
          backgroundColor: Colors.green);
    });
  }

  // Handle user Signed In
  static AuthStateChangeAction<SignedIn> _handleSignIn(BuildContext context) {
    return AuthStateChangeAction<SignedIn>((context, state) async {
      // Check to see if user has provided setups (Name, User Type, etc.)
      DatabaseReference userSettingsRef = FirebaseDatabase.instance.ref();
      final snapshot = await userSettingsRef.child('users/${FirebaseAuth.instance.currentUser!.uid}').get();

      if (snapshot.exists) {
        Navigator.pushReplacementNamed(context, Constants.homeRoute);
      } else {
        Navigator.pushReplacementNamed(context, Constants.firstTimeSignInRoute);
      }
    });
  }

  static Widget buildProfileScreen(BuildContext context) {
    return ProfileScreen(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      actions: [
        _handleSignOut(context),
      ],
    );
  }

  static SignedOutAction _handleSignOut(BuildContext context) {
    return SignedOutAction((context) {
      Navigator.pushReplacementNamed(context, Constants.signInRoute);
    });
  }
}
