import 'package:fbla_application/widgets/quiz_ui/mc_question.dart';
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
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late PageController _pageController;
  int currentPage = 0;
  bool allowTraversal = true;

  //TEMPORARY
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
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isFirstPage {
    return currentPage <= 0;
    // return _pageController.hasClients && (_pageController.page ?? 0) <= 0;
  }

  bool get _isLastPage {
    return currentPage >= pageCount - 2;
    // return _pageController.hasClients && (_pageController.page ?? 0) >= 1;
  }

  List<Widget> constructQuestions(quesitons) {
    List<Widget> questions = quesitons.map<Widget>((question) {
      if (question["questionType"] == "MC") {
        return MCQuestion(question: question);
      } else if (question["questionType"] == "TF") {
        return TfQuestion(question: question);
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

    final List<Widget> questions = constructQuestions(args.quiz["questions"]);
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
                                setState(() {
                                  setPage(currentPage - 1);
                                });
                                _pageController
                                    .previousPage(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut)
                                    .then((value) {});
                              },
                        child: Text("Back"),
                      )
                    : Container(),
                Center(
                  child: Text(
                    args.quiz["questions"][currentPage]["questionTitle"] ??
                        "Question Name",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
                (allowTraversal)
                    ? ElevatedButton(
                        onPressed: _isLastPage
                            ? null
                            : () {
                                setState(() {
                                  setPage(currentPage + 1);
                                });
                                _pageController
                                    .nextPage(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut)
                                    .then((value) {});
                              },
                        child: Text("Next"),
                      )
                    : Container(),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _pageController,
              children: [
                ...questions,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
