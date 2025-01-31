import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('No data available'));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  ProfileImageEditable(
                    profileImageSeed: userData['User Image Seed'] ?? "0",
                  ),
                  SizedBox(height: 16),
                  Text(
                    // ignore: prefer_interpolation_to_compose_strings
                    userData['User First'] + " " + userData['User Last'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    FirebaseAuth.instance.currentUser!.email ?? 'N/A',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    userData['User Type'] ??
                        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
                            'Vestibulum in neque et nisl.',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                          onPressed: () {
                            showDialog(
                                barrierDismissible: true,
                                context: context,
                                builder: (context) => AlertDialog(
                                      title: Text("Confirm"),
                                      content: Text(
                                          "Are you sure you would like to sign out?"),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text("No")),
                                        TextButton(
                                            onPressed: () async {
                                              await FirebaseAuth.instance
                                                  .signOut();
                                              Navigator.pushReplacementNamed(
                                                  context,
                                                  Constants.signInRoute);
                                            },
                                            child: Text("Yes"))
                                      ],
                                    ));
                          },
                          style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all<Color>(
                                  Theme.of(context).colorScheme.errorContainer),
                              foregroundColor: WidgetStateProperty.all<Color>(
                                  Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer)),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                              SizedBox(width: 5),
                              Text("Sign Out")
                            ],
                          )),
                      SizedBox(width: 16),
                      ElevatedButton(
                          onPressed: () {},
                          child: Row(
                            children: [
                              Icon(Icons.settings),
                              SizedBox(width: 5),
                              Text("Settings")
                            ],
                          )),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProfileImageEditable extends StatefulWidget {
  const ProfileImageEditable({super.key, required this.profileImageSeed});

  final String profileImageSeed;

  @override
  _ProfileImageEditableState createState() =>
      _ProfileImageEditableState(profileImageSeed: profileImageSeed);
}

class _ProfileImageEditableState extends State<ProfileImageEditable> {
  String profileImageSeed;
  String newProfileImageSeed = 'CanMan';
  var rnjesus = Random();

  _ProfileImageEditableState({required this.profileImageSeed});

  void updateProfileImageSeed(String newSeed) {
    setState(() {
      newProfileImageSeed = newSeed;
    });
  }

  void changeRootProfileImageSeed(String newSeed) {
    setState(() {
      profileImageSeed = newSeed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          foregroundImage:
              Image.network(Constants.profilePictureRoute + profileImageSeed)
                  .image,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return SimpleDialog(
                        title: Text("Change Profile Picture"),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: CircleAvatar(
                                radius: 75,
                                foregroundImage: Image.network(
                                        Constants.profilePictureRoute +
                                            newProfileImageSeed)
                                    .image,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                var newSeed =
                                    rnjesus.nextInt(999999999).toString();
                                setState(() {
                                  newProfileImageSeed = newSeed;
                                });
                                updateProfileImageSeed(
                                    newSeed); // Update parent state
                              },
                              child: Text("Randomize"),
                            ),
                          ),
                          SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text("Exit")),
                                TextButton(
                                    onPressed: () {
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(FirebaseAuth
                                              .instance.currentUser?.uid)
                                          .update({
                                        'User Image Seed': newProfileImageSeed,
                                      });
                                      changeRootProfileImageSeed(
                                          newProfileImageSeed);
                                      Navigator.pop(context);
                                    },
                                    child: Text("Save")),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
            child: Icon(Icons.edit),
          ),
        ),
      ],
    );
  }
}
