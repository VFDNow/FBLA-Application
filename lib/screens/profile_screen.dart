import 'dart:math';

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ProfileImageEditable(),
              SizedBox(height: 16),
              Text(
                'John Doe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'john.doe@example.com',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 16),
              Text(
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
                                          await FirebaseAuth.instance.signOut();
                                          Navigator.pushReplacementNamed(
                                              context, Constants.signInRoute);
                                        },
                                        child: Text("Yes")),
                                    ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text("No"))
                                  ],
                                ));
                      },
                      style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all<Color>(Colors.redAccent)),
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
      ),
    );
  }
}

class ProfileImageEditable extends StatefulWidget {
  const ProfileImageEditable({super.key});

  @override
  _ProfileImageEditableState createState() => _ProfileImageEditableState();
}

class _ProfileImageEditableState extends State<ProfileImageEditable> {
  String profileImageSeed = 'CanMan';
  var rng = Random();

  void updateProfileImageSeed(String newSeed) {
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
                          CircleAvatar(
                            radius: 100,
                            foregroundImage: Image.network(
                                    Constants.profilePictureRoute +
                                        profileImageSeed)
                                .image,
                          ),
                          SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                var newSeed =
                                    rng.nextInt(0x7FFFFFFFFFFFFFFF).toString();
                                setState(() {
                                  profileImageSeed = newSeed;
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
