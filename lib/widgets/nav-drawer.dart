import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NavigationDrawer extends StatefulWidget {
  const NavigationDrawer({super.key});

  @override
  _NavigationDrawerState createState() => _NavigationDrawerState();
}

class _NavigationDrawerState extends State<NavigationDrawer> {
  Map<String, dynamic>? userData;

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get()
          .then((value) {
        setState(() {
          userData = value.data();
        });
      });

      return Drawer(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Drawer(
        child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildHeader(context, userData),
          Divider(color: Theme.of(context).dividerColor),
          buildMenuItems(context, userData)
        ],
      ),
    ));
  }

  Widget buildHeader(BuildContext context, Map<String, dynamic>? userData) =>
      Container(
        color: Theme.of(context).primaryColor,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primary,
              child: Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 100,
                      backgroundImage: NetworkImage(
                          Constants.profilePictureRoute +
                              userData?['userImageSeed']),
                    ),
                    const SizedBox(height: 10),
                    // ignore: prefer_interpolation_to_compose_strings
                    Text(userData?['userFirst'] + " " + userData?['userLast'],
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary)),
                    const SizedBox(height: 10),
                    Text(userData?['userType'],
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary))
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10)
          ],
        ),
      );

  Widget buildMenuItems(BuildContext context, Map<String, dynamic>? userData) {
    List<StatelessWidget> classes = buildClassList(context, userData);

    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.home),
          title: const Text('Home'),
          onTap: () =>
              Navigator.pushReplacementNamed(context, Constants.homeRoute),
        ),
        Divider(color: Theme.of(context).dividerColor),
        ListTile(
          title: Text(
            "Classes",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          minVerticalPadding: 0,
        ),
        ...classes,
        // Add in each of the classes the user is enrolled in
        ListTile(
          leading: Icon(Icons.add),
          title: Text(userData?['userType'].toString() == "Teacher"
              ? "Create Class"
              : "Join Class"),
          onTap: () => {
            if ((userData?['userType'].toString() ?? "Student") == "Teacher")
              {Navigator.pushNamed(context, Constants.createClassRoute)}
            else
              {Navigator.pushNamed(context, Constants.joinClassRoute)}
          },
        ),
        Divider(color: Theme.of(context).dividerColor),
        ListTile(
          leading: Icon(Icons.person),
          title: const Text('Profile'),
          onTap: () => Navigator.pushNamed(context, Constants.profileRoute),
        ),
        Divider(color: Theme.of(context).dividerColor)
      ],
    );
  }

  List<StatelessWidget> buildClassList(
      BuildContext context, Map<String, dynamic>? userData) {
    if (userData?['classes'] != null) {
      List<StatelessWidget> classes = [];

      var borderColorToggle = true;

      for (var classData in userData?['classes']) {
        classes.add(ListTile(
          titleAlignment: ListTileTitleAlignment.center,
          tileColor: borderColorToggle
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          leading: Icon(Constants
              .subjectIconStringMap[classData['classIcon'] ?? "School"]),
          title: Text(classData['className'] ?? "Class"),
          trailing: Text(classData['teacherName'] ?? "",
              style: Theme.of(context).textTheme.labelSmall),
          onTap: () => {
            Navigator.pushNamed(context, Constants.classHomeRoute,
                arguments: ClassHomeArgs(classData["classId"] ?? ""))
          },
        ));
        borderColorToggle = !borderColorToggle;
      }

      return classes;
    }
    return [];
  }
}
