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
                  ProfileImageEditable(profileImageSeed: userData['User Image Seed'] ?? "0",),
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
                                        ElevatedButton(
                                            onPressed: () async {
                                              await FirebaseAuth.instance
                                                  .signOut();
                                              Navigator.pushReplacementNamed(
                                                  context,
                                                  Constants.signInRoute);
                                            },
                                            child: Text("Yes")),
                                        ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text("No"))
                                      ],
                                    ));
                          },
                          style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all<Color>(
                                  Colors.redAccent)),
                          child: Row(
                            children: [
                              Icon(Icons.person),
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
  _ProfileImageEditableState createState() => _ProfileImageEditableState();
}

class _ProfileImageEditableState extends State<ProfileImageEditable> {
  String newProfileImageSeed = 'CanMan';
  var rng = Random();

  void updateProfileImageSeed(String newSeed) {
    setState(() {
      newProfileImageSeed = newSeed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          foregroundImage:
              Image.network(Constants.profilePictureRoute + newProfileImageSeed)
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
                          CircleAvatar(
                            radius: 100,
                            foregroundImage: Image.network(
                                    Constants.profilePictureRoute +
                                        newProfileImageSeed)
                                .image,
                          ),
                          SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                var newSeed =
                                    rng.nextInt(99999999).toString();
                                setState(() {
                                  newProfileImageSeed = newSeed;
                                });
                                updateProfileImageSeed(
                                    newSeed); // Update parent state
                              },
                              child: Text("Change Picture"),
                            ),
                          ),
                          SizedBox(height: 16),
                          SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text("Confirm"),
                          ),
                          SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text("Cancel"),
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
