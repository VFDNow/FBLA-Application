import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:fbla_application/screens/teacher_home_screen.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/widgets/class_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide NavigationDrawer;
import 'package:fbla_application/widgets/nav-drawer.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map<String, dynamic>? userData;
  
  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      if (FirebaseAuth.instance.currentUser == null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Home'),
          ),
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get()
          .then((value) {
        setState(() {
          userData = value.data();
        });
      });

      return Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Redirect teachers to the teacher home screen
    if ((userData?["userType"] ?? "Student") == "Teacher") {
      return TeacherHomeScreen();
    }

    // Continue with the student view
    List<Widget> classCards = buildClassCards(context, userData!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Center(
          child: Column(
            children: <Widget>[
              Container(
                // padding: const EdgeInsets.all(16),
                width: double.infinity,
                height: 200,
                color: Theme.of(context).colorScheme.primary,
                child: Center(
                  child: Text(
                    'Welcome, ${userData?['userFirst']}!',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
                      child: Text('My Classes',
                          style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 30,
                          children: [
                            BasicAdditionCard(onTap: () {
                              Navigator.pushNamed(
                                  context,
                                  (userData?["userType"] ?? "Student") ==
                                          "Student"
                                      ? Constants.joinClassRoute
                                      : Constants.createClassRoute);
                            }),
                            ...classCards,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      drawer: const NavigationDrawer(),
    );
  }

  List<Widget> buildClassCards(
      BuildContext context, Map<String, dynamic> userData) {
    List<Widget> classCards = [];

    if (userData["classes"] != null) {
      for (Map<String, dynamic> classData in userData["classes"]) {
        classCards.add(ClassCard(
            className: classData["className"] ?? "Class",
            teacherName: classData["teacherName"] ?? "Teacher",
            onTap: () {
              Navigator.pushNamed(context, Constants.classHomeRoute,
                  arguments: ClassHomeArgs(classData["classId"] ?? ""));
            }));
      }
    }

    return classCards;
  }
}
