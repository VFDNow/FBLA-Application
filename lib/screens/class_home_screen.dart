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
      body: Center(
        child: Column(
          children: [
            Text(classData?["className"] ?? "Error"),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, Constants.quizRoute,
                    arguments: QuizScreenArgs(
                        quiz: Map<String, dynamic>.from({
                      "quizName": "Name",
                      "quizDesc": "Description Here",
                      "shuffleOrder": true,
                      "allowTraversal": false,
                      "allowAIGrading": true,
                      "authors": ["Author A", "Author B"],
                      "questions": [
                        {
                          "questionId": '0',
                          "questionType": "MC",
                          "questionTitle":
                              "Nerds",
                          "questionBody":
                              "What is the capital of Wisconsin?",
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
                          // "correctAnswer": true
                        },
                        {
                          "questionId": "2",
                          "questionType": "SA",
                          "questionTitle":
                              "What is the evaluation of this text here?",
                          "questionBody": "The correct answer is abcdefg.",
                          "singleWord": true,
                          "answers": ["abcdefg"]
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
