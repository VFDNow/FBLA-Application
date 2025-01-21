import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';

class FirebaseAuthConfig {
  static void configureProviders() {
    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
      GoogleProvider(
          clientId:
              "130467636176-5gsslu04l2qu14mg2tkc9431a1r09bpp.apps.googleusercontent.com")
    ]);
  }
}
