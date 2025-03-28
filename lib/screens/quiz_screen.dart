import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/utils/grader.dart';
import 'package:fbla_application/widgets/quiz_ui/la_question.dart';
import 'package:fbla_application/widgets/quiz_ui/mc_question.dart';
import 'package:fbla_application/widgets/quiz_ui/quiz_results_screen.dart';
import 'package:fbla_application/widgets/quiz_ui/quiz_review_screen.dart';
import 'package:fbla_application/widgets/quiz_ui/sa_question.dart';
import 'package:fbla_application/widgets/quiz_ui/tf_question.dart';
import 'package:fbla_application/widgets/error_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide ErrorWidget;

class QuizScreenArgs {
  final Map<String, dynamic> quiz;
  final String quizId;

  const QuizScreenArgs({required this.quiz, this.quizId = ""});
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  QuizScreenState createState() => QuizScreenState();
}

enum QuestionState { unanswered, grading, correct, incorrect }

class QuizScreenState extends State<QuizScreen> {
  late PageController _pageController;
  int currentPage = 0;
  bool allowTraversal = true;
  QuestionState currentState = QuestionState.unanswered;

  Map<String, dynamic>? userAnswers = <String, dynamic>{};
  Map<String, dynamic> answerData = <String, bool>{};
  bool reviewMode = false;

  int pageCount = 3;

  void setPage(int newPage) {
    currentPage = newPage;
    if (currentPage < 0) {
      currentPage = 0;
    } else if (currentPage >= pageCount) {
      currentPage = pageCount - 1;
    }
  }

  Future<bool> publishResults(Map<String, dynamic> quizData,
      String assignmentId, List<bool> scores) async {
    bool success = true;
    if (assignmentId.isEmpty || quizData["classId"] == null) {
      return false;
    }
    int stars = Grader().getStarValue(quizData["questions"], scores);
    final ref = FirebaseFirestore.instance
        .collection("classes")
        .doc(quizData["classId"])
        .collection("quizHistory")
        .doc();
    await ref.set({
      "userId": FirebaseAuth.instance.currentUser?.uid,
      "assignmentId": assignmentId,
      "results": scores,
      "timestamp": Timestamp.now(),
      "stars": stars,
    }).onError((error, stackTrace) {
      success = false;
    });
    return success;
  }

  void traversalSwitchToResults(quizData) {
    setState(() {
      currentState = QuestionState.grading;
    });
    switchToResults(quizData);
  }

  void switchToResults(quiz) async {
    List<bool> scores = [];

    if (allowTraversal) {
      scores = await Grader().gradeQuiz(quiz, userAnswers ?? {});
    } else {
      for (var question in quiz["questions"]) {
        if (answerData.containsKey(question["questionId"])) {
          scores.add(answerData[question["questionId"]] ?? false);
        } else {
          scores.add(false);
        }
      }
    }

    // Capture the arguments before the async operation
    final String quizId = (ModalRoute.of(context)!.settings.arguments as QuizScreenArgs).quizId;

    bool res = await publishResults(quiz, quizId, scores);

    // Check if widget is still in the tree after async operation
    if (!mounted) return;

    if (!res) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error publishing results"),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Results published successfully"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    // Only navigate if still mounted
    if (mounted) {
      Navigator.pushReplacementNamed(context, Constants.quizResultsRoute,
          arguments: QuizResultsArgs(quiz: quiz, scores: scores));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as QuizScreenArgs?;
    if (args != null) {
      pageCount = args.quiz["questions"].length;
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    onAnswer = (Map<String, dynamic> question, answer) {
      if (allowTraversal) {
        setState(() {
          userAnswers?[question["questionId"]] = answer;
        });
      } else {
        if (QuestionState.unanswered != currentState) {
          return;
        }

        setState(() {
          currentState = QuestionState.grading;
        });

        Map<String, dynamic> answerTmp = {
          question["questionId"].toString(): answer
        };
        Grader().gradeQuestion(question, answerTmp).then((value) {
          setState(() {
            currentState =
                value ? QuestionState.correct : QuestionState.incorrect;
            answerData[question["questionId"]] = value;
          });
        });
      }
    };

    questionArea = (context, questions, quizData) {
      return Expanded(
        child: Stack(
          fit: StackFit.expand, // Make the stack fill its parent
          children: [
            PageView(
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                // setState(() {
                //   setPage(index);
                // });
              },
              controller: _pageController,
              children: questions,
            ),

            // Conditional overlays based on state
            if (currentState == QuestionState.grading)
              Container(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer, // Semi-transparent background
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("Grading...", style: TextStyle(color: Colors.white)),
                      SizedBox(height: 10),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),

            if (currentState == QuestionState.correct)
              GestureDetector(
                onTap: () {
                  setState(() {
                    currentState = QuestionState.unanswered;
                    if (!_isLastPage) {
                      setPage(currentPage + 1);
                      Future.delayed(Duration(milliseconds: 50), () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      });
                    } else {
                      switchToResults(quizData);
                    }
                  });
                },
                child: Container(
                  color: Colors.green,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.white, size: 100),
                        Text("Correct!",
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(color: Colors.white)),
                        Text("Press anywhere to continue.",
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),

            if (currentState == QuestionState.incorrect)
              GestureDetector(
                onTap: () {
                  setState(() {
                    currentState = QuestionState.unanswered;
                    if (!_isLastPage) {
                      setPage(currentPage + 1);
                      Future.delayed(Duration(milliseconds: 50), () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      });
                    } else {
                      switchToResults(quizData);
                    }
                  });
                },
                child: Container(
                  color: Colors.red,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel, color: Colors.white, size: 100),
                        Text("Incorrect!",
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(color: Colors.white)),
                        Text("Press anywhere to continue.",
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),

            if (reviewMode)
              QuizReviewScreen(
                quizData: quizData,
                answers: userAnswers!,
                onSubmit: (quizData) {
                  setState(() {
                    currentState = QuestionState.grading;
                    reviewMode = false;
                  });
                  traversalSwitchToResults(quizData);
                },
              )
          ],
        ),
      );
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isFirstPage {
    return currentPage <= 0;
  }

  bool get _isLastPage {
    return currentPage >= pageCount - 1;
  }

  late Function onAnswer;
  late Function questionArea;

  List<Widget> constructQuestions(quesitons) {
    List<Widget> questions = quesitons.map<Widget>((question) {
      if (question["questionType"] == "MC") {
        return MCQuestion(
          question: question,
          onAnswer: onAnswer,
          currentAnswer: userAnswers?[question["questionId"]],
        );
      } else if (question["questionType"] == "TF") {
        return TfQuestion(
          question: question,
          onAnswer: onAnswer,
          currentAnswer: userAnswers?[question["questionId"]],
        );
      } else if (question["questionType"] == "SA") {
        return SaQuestion(
          question: question,
          onAnswer: onAnswer,
          allowTraversal: allowTraversal,
        );
      } else if (question["questionType"] == "LA") {
        return LaQuestion(
          question: question,
          onAnswer: onAnswer,
          allowTraversal: allowTraversal,
        );
      }
      return Container();
    }).toList();
    return questions;
  }

  @override
  Widget build(BuildContext context) {
    QuizScreenArgs args;
    try {
      args = ModalRoute.of(context)!.settings.arguments as QuizScreenArgs;
    } catch (error) {
      return ErrorWidget(errorMessage: "Error Loading Quiz");
    }

    final questionData = args.quiz["questions"];
    final List<Widget> questions = constructQuestions(questionData);
    setState(() {
      allowTraversal = args.quiz["allowTraversal"] ?? true;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(args.quiz["quizName"] ?? "Quiz Name"),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14.0),
            width: double.infinity,
            color: Theme.of(context).primaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                (allowTraversal)
                    ? ElevatedButton(
                        onPressed: (_isFirstPage ||
                                currentState != QuestionState.unanswered)
                            ? null
                            : () {
                                if (!reviewMode) {
                                  setState(() {
                                    setPage(currentPage - 1);
                                  });
                                  _pageController
                                      .previousPage(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut)
                                      .then((value) {});
                                } else {
                                  setState(() {
                                    reviewMode = false;
                                  });
                                }
                              },
                        child: Text("Back"),
                      )
                    : Container(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        (reviewMode)
                            ? "Review & Submit"
                            : questionData[currentPage]["questionTitle"] ??
                                "Question Name",
                        softWrap: true,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                overflow: TextOverflow.clip),
                      ),
                    ),
                  ),
                ),
                (allowTraversal)
                    ? ElevatedButton(
                        onPressed: (_isLastPage)
                            ? (!reviewMode &&
                                    currentState == QuestionState.unanswered
                                ? () {
                                    setState(() {
                                      reviewMode = true;
                                    });
                                  }
                                : null)
                            : () {
                                setState(() {
                                  setPage(currentPage + 1);
                                });
                                _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut);
                              },
                        child: Text("Next"),
                      )
                    : Container(),
              ],
            ),
          ),
          questionArea(context, questions, args.quiz),
        ],
      ),
    );
  }
}
