import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:fbla_application/screens/teacher_class_home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NavigationDrawer extends StatefulWidget {
  const NavigationDrawer({super.key});

  @override
  _NavigationDrawerState createState() => _NavigationDrawerState();
}

class _NavigationDrawerState extends State<NavigationDrawer> {
  Map<String, dynamic>? userData;
  // For teachers, we'll group classes by name
  Map<String, List<Map<String, dynamic>>> groupedClasses = {};
  bool isTeacher = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get();

    Map<String, dynamic>? userDataMap = userDoc.data() as Map<String, dynamic>?;

    isTeacher = (userDataMap?["userType"] ?? "Student") == "Teacher";

    if (isTeacher) {
      // For teachers, fetch and group their classes
      QuerySnapshot classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('owner', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .get();

      // Group by class name
      Map<String, List<Map<String, dynamic>>> classes = {};
      for (var doc in classesSnapshot.docs) {
        Map<String, dynamic> classData = doc.data() as Map<String, dynamic>;
        classData['classId'] = doc.id;

        String className = classData['className'] ?? 'Unnamed Class';
        if (!classes.containsKey(className)) {
          classes[className] = [];
        }
        classes[className]!.add(classData);
      }

      setState(() {
        userData = userDataMap;
        groupedClasses = classes;
      });
    } else {
      // For students, just set the user data
      setState(() {
        userData = userDataMap;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      );
    }

    // Calculate drawer height and appropriate sizes
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * 0.25; // 25% of screen height for header
    final avatarSize = headerHeight * 0.4; // 40% of header height for avatar

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: headerHeight,
            child: DrawerHeader(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: avatarSize / 2,
                    backgroundImage: NetworkImage(
                        Constants.profilePictureRoute +
                            userData?['userImageSeed']),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "${userData?['userFirst']} ${userData?['userLast']}",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    userData?['userType'] ?? '',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: const Text('Home'),
            onTap: () =>
                Navigator.pushReplacementNamed(context, Constants.homeRoute),
          ),
          Divider(color: Theme.of(context).dividerColor),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Classes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isTeacher)
            ...buildTeacherClassItems(context)
          else
            ...buildStudentClassItems(context),
          Divider(color: Theme.of(context).dividerColor),
          ListTile(
            leading: Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () => Navigator.pushNamed(context, Constants.profileRoute),
          ),
          Divider(color: Theme.of(context).dividerColor)
        ],
      ),
    );
  }

  List<Widget> buildTeacherClassItems(BuildContext context) {
    List<Widget> items = [];

    // Add classes grouped by name
    groupedClasses.forEach((className, sections) {
      items.add(ListTile(
        title: Text(className),
        leading: Icon(
          Constants.subjectIconStringMap[sections.first['classIcon']] ??
              Icons.book,
        ),
        trailing:
            sections.length > 1 ? Text('${sections.length} sections') : null,
        onTap: () {
          // Navigate to the teacher class home page, passing the class name and all section IDs
          List<String> sectionIds =
              sections.map((section) => section['classId'].toString()).toList();
          Navigator.pushNamed(context, Constants.teacherClassHomeRoute,
              arguments: TeacherClassHomeArgs(
                  className, sectionIds, sections.first['classIcon']));
        },
      ));
    });

    // Add create class option
    items.add(ListTile(
      title: const Text('Create Class'),
      leading: const Icon(Icons.add),
      onTap: () {
        Navigator.pushNamed(context, Constants.createClassRoute).then((value) {
          setState(() {
            userData = null; // Reset user data to force reload
          });
        });
      },
    ));

    return items;
  }

  List<Widget> buildStudentClassItems(BuildContext context) {
    List<Widget> items = [];

    // Original student class list
    if (userData != null && userData!["classes"] != null) {
      for (Map<String, dynamic> classData in userData!["classes"]) {
        items.add(
          ListTile(
            title: Text(classData["className"] ?? "Class"),
            leading: Icon(
              Constants.subjectIconStringMap[classData["classIcon"] ?? "General"],
            ),
            onTap: () {
              Navigator.pushNamed(context, Constants.classHomeRoute,
                  arguments: ClassHomeArgs(classData["classId"] ?? ""));
            },
          ),
        );
      }
    }

    // Join class option
    items.add(ListTile(
      title: const Text('Join Class'),
      leading: const Icon(Icons.add),
      onTap: () {
        Navigator.pushNamed(context, Constants.joinClassRoute).then((value) {
          setState(() {
            userData = null; // Reset user data to force reload
          });
        });
      },
    ));

    return items;
  }
}
