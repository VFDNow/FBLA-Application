import 'package:fbla_application/widgets/quiz_ui/quiz_question.dart';
import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late PageController _pageController;

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
    print(_pageController.hasClients);
    return _pageController.hasClients && (_pageController.page ?? 0) <= 0;
  }

  bool get _isLastPage {
    return _pageController.hasClients && (_pageController.page ?? 0) >= 1;
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
                            setState(() {});
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
                            setState(() {});
                          });
                        },
                  child: Text("Next"),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              children: [
                QuizQuestion(
                  question: {
                    "answers": [
                      {"answerBody": "Badeebadoo"},
                      {"answerBody": "Gyatlers"},
                      {"answerBody": "Rizzlers"},
                      {"answerBody": "Sigmas"},
                      {"answerBody": "Gooners"},
                    ]
                  },
                ),
                QuizQuestion(
                  question: {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
