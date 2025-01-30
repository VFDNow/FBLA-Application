import 'package:cloud_firestore/cloud_firestore.dart';
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
        Navigator.pushReplacementNamed(context, Constants.firstTimeSignInRoute);

        GlobalWidgets(context).showSnackBar(
          content: "User Created Succesfully!",
          backgroundColor: Colors.green);
        
        return;
      }

      Navigator.pushReplacementNamed(context, Constants.firstTimeSignInRoute);

      GlobalWidgets(context).showSnackBar(
          content: "User Created Succesfully!\nPlease Sign In.",
          backgroundColor: Colors.green);
    });
  }

  // Handle user Signed In
  static AuthStateChangeAction<SignedIn> _handleSignIn(BuildContext context) {
    return AuthStateChangeAction<SignedIn>((context, state) async {
      
      // Check to see if user has provided setups (Name, User Type, etc.)
      final db = FirebaseFirestore.instance;
      // const querySnapshot = await 
      db.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get().then((value) {
        GlobalWidgets(context).showSnackBar(
        content: "Signed In!",
        backgroundColor: Colors.green);
        if (value.data() == null) {
          Navigator.pushReplacementNamed(context, Constants.firstTimeSignInRoute);
        } else {
          Navigator.pushReplacementNamed(context, Constants.homeRoute);
        }
      }).onError((object, stackTrace) {
        GlobalWidgets(context).showSnackBar(
        content: "Error Signing In!",
        backgroundColor: Colors.red);
      });
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
