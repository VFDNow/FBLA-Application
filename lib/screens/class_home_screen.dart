import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/screens/quiz_screen.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/utils/global_widgets.dart';
import 'package:fbla_application/widgets/assignment_card.dart';
import 'package:fbla_application/widgets/error_screen.dart';
import 'package:fbla_application/widgets/user_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart' hide ErrorWidget;

class ClassHomeArgs {
  final String classId;

  ClassHomeArgs(this.classId);
}

class ClassHome extends StatefulWidget {
  const ClassHome({super.key});

  @override
  _ClassHomeState createState() => _ClassHomeState();
}

class _ClassHomeState extends State<ClassHome> {
  Map<String, dynamic>? classData;
  bool isLoading = false;

  Future<Map<String, dynamic>> getQuizData(String quizName) async {
    var storageRef = FirebaseStorage.instance.ref();
    storageRef = storageRef.child("quizzes/$quizName.json");

    final Uint8List? data = await storageRef.getData();

    if (data == null) {
      throw Exception("Failed to load quiz data");
    }

    return jsonDecode(utf8.decode(data));
  }

  @override
  Widget build(BuildContext context) {
    final ClassHomeArgs args;
    try {
      args = ModalRoute.of(context)!.settings.arguments as ClassHomeArgs;
    } catch (error) {
      return Scaffold(
        body: ErrorWidget(errorMessage: "Error Loading Class"),
      );
    }

    if (classData == null) {
      FirebaseFirestore.instance
          .collection("classes")
          .doc(args.classId)
          .get()
          .then((value) => {
                setState(() {
                  classData = value.data();
                })
              });

      return Scaffold(
        appBar: AppBar(
          title: const Text('Class Home'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Class Home'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                "Loading Quiz...",
                style: Theme.of(context).textTheme.headlineMedium,
              )
            ],
          ),
        ),
      );
    }

    Map<String, dynamic> groups = classData?["groups"] ?? {};
    String userGroup = "None";
    for (var group in groups.keys) {
      var groupData = groups[group];
      for (var member in groupData["members"]) {
        if ((member["uId"] ?? "=1234") ==
            FirebaseAuth.instance.currentUser?.uid) {
          userGroup = group;
          break;
        }
      }
    }

    buildAssignmentWidgets(BuildContext context) {
      List<Widget> result = [];

      for (var assignment in classData?["assignments"] ?? []) {
        result.add(AssignmentCard(
          assignmentName: assignment["assignmentName"],
          dueDate: (assignment["dueDate"] as Timestamp).toDate(),
          onTap: () {
            setState(() {
              isLoading = true;
            });
            getQuizData(assignment["quizPath"] ?? "notHere").then((value) {
              setState(() {
                isLoading = false;
              });
              if (mounted) {
                Navigator.pushNamed(context, Constants.quizRoute,
                    arguments: QuizScreenArgs(quiz: value));
              }
            }).onError((error, stackTrace) {
              setState(() {
                isLoading = false;
              });
              if (mounted) {
                GlobalWidgets(context).showSnackBar(
                    content: "Error loading quiz.",
                    backgroundColor: Theme.of(context).colorScheme.error);
              }
            });
          },
        ));
      }
      return result;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text((classData?["className"] ?? "Error") + " Home"),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              // padding: const EdgeInsets.all(16),
              width: double.infinity,
              height: 200,
              color: Theme.of(context).colorScheme.primary,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Constants.subjectIconStringMap[
                                classData?["classIcon"] ?? "General"] ??
                            Icons.error,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 50,
                      ),
                      Text(
                        classData?["className"] ?? "Error",
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary),
                      ),
                      Text(
                        classData?["classHour"] ?? "Error",
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            (userGroup == "None")
                ? Container(
                    width: double.infinity,
                    height: 250,
                    color: Theme.of(context).colorScheme.secondary,
                    child: Center(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 150,
                        ),
                        Text(
                          "You are not in any group!",
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary),
                        ),
                        Text(
                          "Ask your teacher to assign you to a group.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary),
                        ),
                      ],
                    )),
                  )
                : Container(
                    // padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    height: 250,
                    color: Theme.of(context).colorScheme.secondary,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Constants.groupNameIconStringMap[userGroup] ??
                                  Icons.error,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 150,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  userGroup,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary),
                                ),
                                SizedBox(
                                  height: 150,
                                  width: 250,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount:
                                        groups[userGroup]?["members"].length ??
                                            0,
                                    itemBuilder: (context, index) {
                                      return UserCard(
                                          name: groups[userGroup]?["members"]
                                                  [index]["name"] ??
                                              "Unknown",
                                          icon: groups[userGroup]?["members"]
                                                  [index]["icon"] ??
                                              "default");
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            SizedBox(
                height: 400,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text("Class Standings",
                          style: Theme.of(context).textTheme.headlineMedium),
                      Divider(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            String current = groups.keys.elementAt(index);
                            return ListTile(
                              leading: Icon(
                                  Constants.groupNameIconStringMap[current] ??
                                      Icons.error),
                              title: Text(current),
                              subtitle: Text("Score: ${index * 10}"),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )),
            Text("Assignments",
                style: Theme.of(context).textTheme.headlineMedium),
            Divider(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [...buildAssignmentWidgets(context)],
                  )),
            ),
            SizedBox(
              height: 100,
            )
          ],
        ),
      ),
    );
  }
}
