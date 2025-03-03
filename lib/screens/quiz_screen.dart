import 'package:fbla_application/widgets/quiz_ui/mc_question.dart';
import 'package:fbla_application/widgets/quiz_ui/tf_question.dart';
import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late PageController _pageController;
  int currentPage = 0;

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
    return currentPage >= pageCount - 1;
    // return _pageController.hasClients && (_pageController.page ?? 0) >= 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Name'),
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
                ElevatedButton(
                  onPressed: _isFirstPage
                      ? null
                      : () {
                          _pageController
                              .previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut)
                              .then((value) {
                            setState(() {
                              setPage(currentPage - 1);
                            });
                          });
                        },
                  child: Text("Back"),
                ),
                Center(
                  child: Text(
                    'Question Title',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isLastPage
                      ? null
                      : () {
                          _pageController
                              .nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut)
                              .then((value) {
                            setState(() {
                              setPage(currentPage + 1);
                            });
                          });
                        },
                  child: Text("Next"),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
                physics: const NeverScrollableScrollPhysics(),
              controller: _pageController,
              children: [
                MCQuestion(
                  question: {
                    "questionTitle": "Real Question",
                    "questionBody": "Sigma Sigma on the Wall, who'se the most Skibidi of them all?",
                    "answers": [
                      {"answerBody": "Badeebadoo"},
                      {"answerBody": "Gyatlers"},
                      {"answerBody": "Rizzlers"},
                      {"answerBody": "Sigmas"},
                      {"answerBody": "Gooners", "answerIcon": "clean"},
                      {"answerBody": "Rizzlers"},
                      {"answerBody": "Sigmas"},
                      {"answerBody": "Gooners", "answerIcon": "clean"},
                    ]
                  },
                ),
                TfQuestion(
                  question: {},
                ),
                MCQuestion(
                  question: {
                    "questionTitle": "Real Question",
                    "questionBody": "Sigma Sigma on the Wall, who'se the most Skibidi of them all?",
                    "answers": [
                      {"answerBody": "Badeebadoo"},
                      {"answerBody": "Gyatlers"},
                      {"answerBody": "Rizzlers"},
                      {"answerBody": "Sigmas"},
                      {"answerBody": "Gooners", "answerIcon": "clean"},
                      {"answerBody": "Rizzlers"},
                      {"answerBody": "Sigmas"},
                      {"answerBody": "Gooners", "answerIcon": "clean"},
                    ]
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
