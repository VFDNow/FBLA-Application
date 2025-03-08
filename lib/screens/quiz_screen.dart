import 'package:fbla_application/utils/grader.dart';
import 'package:fbla_application/widgets/quiz_ui/la_question.dart';
import 'package:fbla_application/widgets/quiz_ui/mc_question.dart';
import 'package:fbla_application/widgets/quiz_ui/quiz_review_screen.dart';
import 'package:fbla_application/widgets/quiz_ui/sa_question.dart';
import 'package:fbla_application/widgets/quiz_ui/tf_question.dart';
import 'package:fbla_application/widgets/error_screen.dart';
import 'package:flutter/material.dart' hide ErrorWidget;

class QuizScreenArgs {
  final Map<String, dynamic> quiz;

  const QuizScreenArgs({required this.quiz});
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
        userAnswers?[question["questionId"]] = answer;
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
        );
      } else if (question["questionType"] == "TF") {
        return TfQuestion(
          question: question,
          onAnswer: onAnswer,
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
                        onPressed: _isFirstPage
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
                Center(
                  child: Text(
                    (reviewMode)
                        ? "Review & Submit"
                        : questionData[currentPage]["questionTitle"] ??
                            "Question Name",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
                (allowTraversal)
                    ? ElevatedButton(
                        onPressed: _isLastPage
                            ? (!reviewMode
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
