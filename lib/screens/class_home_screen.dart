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
import 'package:share_plus/share_plus.dart';

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
  List<Map<String, dynamic>>? userQuizHistory;
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

    if (userQuizHistory == null) {
      FirebaseFirestore.instance
          .collection("classes")
          .doc(args.classId)
          .collection("quizHistory")
          .where("userId",
              isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? "notFound")
          .get()
          .then((value) => {
                setState(() {
                  userQuizHistory = value.docs.map((e) => e.data()).toList();
                  print(userQuizHistory.toString());
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

    List<String> groupStandings = groups.keys.toList();
    // Sort the groups by their scores in descending order (highest first)
    groupStandings.sort((a, b) {
      // Get the scores, defaulting to 0 if not present
      int scoreA = groups[a]?["score"] ?? 0;
      int scoreB = groups[b]?["score"] ?? 0;
      // Sort in descending order (higher scores first)
      return scoreB.compareTo(scoreA);
    });

    buildAssignmentWidgets(BuildContext context) {
      List<Widget> result = [];

      if (userGroup == "None") {
        result.add(Center(
          child: Row(
            children: [
              Icon(
                Icons.error,
                size: 50,
                color: Colors.amberAccent,
              ),
              SizedBox(width: 20),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("You are not in any group!",
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text(
                      "Ask your teacher to assign you to a group to access assignments.",
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ));
        return result;
      }

      for (var assignment in classData?["assignments"] ?? []) {
        AssignmentState assignmentState = AssignmentState.notStarted;

        if ((assignment["dueDate"] as Timestamp).compareTo(Timestamp.now()) <
            0) {
          assignmentState = AssignmentState.missed;
        }

        Map<String, dynamic>? historyRef;

        if (userQuizHistory != null) {
          for (var history in userQuizHistory!) {
            if (history["assignmentId"] == assignment["assignmentId"]) {
              assignmentState = AssignmentState.completed;
              historyRef = history;
            }
          }
        }

        result.add(AssignmentCard(
          assignmentName: assignment["assignmentName"],
          dueDate: (assignment["dueDate"] as Timestamp).toDate(),
          assignmentState: assignmentState,
          results:
              historyRef != null ? historyRef["results"] as List<dynamic> : [],
          onTap: () {
            // Capture assignment details before async operations
            final String quizPath = assignment["quizPath"] ?? "notHere";
            final String assignmentId = assignment["assignmentId"];
            
            setState(() {
              isLoading = true;
            });
            
            getQuizData(quizPath).then((value) {
              // Check if widget is still in tree before updating state
              if (!mounted) return;
              
              setState(() {
                isLoading = false;
              });
              
              Navigator.pushNamed(context, Constants.quizRoute,
                  arguments: QuizScreenArgs(
                      quiz: value, quizId: assignmentId)
              ).then((value) {
                // Check if widget is still in tree before updating state
                if (!mounted) return;
                
                setState(() {
                  userQuizHistory = null;
                });
              });
            }).onError((error, stackTrace) {
              // Check if widget is still in tree before updating state
              if (!mounted) return;
              
              setState(() {
                isLoading = false;
              });
              
              // Pre-capture the context-dependent objects
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final errorColor = Theme.of(context).colorScheme.error;
              
              scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text("Error loading quiz."),
                    backgroundColor: errorColor
                  )
              );
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
                : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
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
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Constants.groupNameIconStringMap[userGroup] ??
                                        Icons.error,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: 150,
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Share.share(
                                              "Team $userGroup is on a mission to reach the top of the leaderboard in ${classData?["className"] ?? "class"}! Join us in completing our assignments and earning points. Together we can win this! 💪🔥 #TeamSuccess #${userGroup.replaceAll(" ", "")}")
                                          .then((result) {
                                        if (result.status ==
                                                ShareResultStatus.success &&
                                            context.mounted) {
                                          GlobalWidgets(context).showSnackBar(
                                              content: "Rally Sent!",
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary);
                                        }
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                    ),
                                    child: SizedBox(
                                      width:
                                          100, // Set a fixed width for the button content
                                      child: Row(
                                        children: [
                                          Icon(Icons.share),
                                          Expanded(
                                            child: Center(
                                              child: Text("Rally Group", textAlign: TextAlign.center,),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                ],
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
                                    // height: 150,
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
                          itemCount: groupStandings.length,
                          itemBuilder: (context, index) {
                            String current =
                                groupStandings[index]; // Use the sorted list
                            return ListTile(
                              leading: Icon(
                                  Constants.groupNameIconStringMap[current] ??
                                      Icons.error),
                              title: Text(current),
                              // Use the actual score from the data instead of index * 10
                              subtitle: Text("#${index + 1}"),
                              trailing: Container(
                                width: 150,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 30,
                                    ),
                                    Card(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        child: SizedBox(
                                          width: 100,
                                          height: 50,
                                          child: Center(
                                            child: Text(
                                              "${groups[current]?["score"] ?? 0}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall,
                                            ),
                                          ),
                                        )),
                                  ],
                                ),
                              ),
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
