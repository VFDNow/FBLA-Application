import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/screens/quiz_screen.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/widgets/error_screen.dart';
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
                          itemCount: Constants.groupNameIconStringMap.length,
                          itemBuilder: (context, index) {
                            String current = Constants
                                .groupNameIconStringMap.keys
                                .elementAt(index);
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
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, Constants.quizRoute,
                    arguments: QuizScreenArgs(
                        quiz: Map<String, dynamic>.from({
                      "quizName": "Name",
                      "quizDesc": "Description Here",
                      "shuffleOrder": true,
                      "allowTraversal": true,
                      "allowAIGrading": true,
                      "authors": ["Author A", "Author B"],
                      "questions": [
                        {
                          "questionId": '0',
                          "questionType": "MC",
                          "questionTitle": "Nerds",
                          "questionBody": "What is the capital of Wisconsin?",
                          "embeds": [
                            "https://media.istockphoto.com/id/839295596/photo/six-pre-teen-friends-piggybacking-in-a-park-close-up-portrait.jpg?s=612x612&w=0&k=20&c=MWkFYzpRSvO1dRql3trV4k6ECO-rTy4HgF8OxrtUkH8=",
                            "FiREBASE STORAGE IMAGE"
                          ],
                          "correctAnswers": [0],
                          "answers": [
                            {
                              "answerId": 0,
                              "answerBody": "Madison",
                              "answerIcon": "iconName"
                            },
                            {
                              "answerId": 1,
                              "answerBody": "Milwaukee",
                              "answerIcon": "iconName"
                            },
                            {
                              "answerId": 2,
                              "answerBody": "Ozaukee",
                              "answerIcon": "iconName"
                            },
                            {
                              "answerId": 3,
                              "answerBody": "Washington D.C.",
                              "answerIcon": "iconName"
                            }
                          ]
                        },
                        {
                          "questionId": "1",
                          "questionType": "TF",
                          "questionTitle":
                              "What is the evaluation of this text here?",
                          "questionBody": "The correct answer is True.",
                          "correctAnswer": true
                        },
                        {
                          "questionId": "2",
                          "questionType": "SA",
                          "questionTitle": "Wisconsin Capital",
                          "questionBody": "What is the capital of Wisconsin?",
                          "singleWord": true,
                          "answers": ["Madison"]
                        },
                        {
                          "questionId": "3",
                          "questionType": "LA",
                          "questionTitle": "Wisconsin Capital",
                          "questionBody":
                              "Write a bit about the capital of Wisconsin?",
                          "singleWord": true,
                          "criteria":
                              "Needs to say the capital is madison, and needs to mention the University of Wisconsin that resides in madison.",
                        }
                      ]
                    })));
              },
              child: Text("Take Quiz"),
            ),
          ],
        ),
      ),
    );
  }
}
