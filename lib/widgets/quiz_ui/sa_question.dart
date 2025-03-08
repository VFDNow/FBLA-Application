import 'dart:math';
import 'package:fbla_application/screens/quiz_screen.dart';
import 'package:flutter/material.dart';

class SaQuestion extends StatefulWidget {
  const SaQuestion(
      {super.key,
      required this.question,
      required this.onAnswer,
      this.allowTraversal = true});

  final Map<String, dynamic> question;
  final Function onAnswer;
  final bool allowTraversal;
  @override
  _SaQuestionState createState() => _SaQuestionState();
}

class _SaQuestionState extends State<SaQuestion> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Initialize the controller
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Try to get any existing answer from userAnswers map
    final questionId = widget.question["questionId"];
    final quizState = context.findAncestorStateOfType<QuizScreenState>();
    if (quizState != null &&
        quizState.userAnswers != null &&
        quizState.userAnswers!.containsKey(questionId)) {
      _controller.text = quizState.userAnswers![questionId];
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // Clean up controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var questionBody = widget.question['questionBody'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final answersHeight = constraints.maxHeight / 1.6;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Text(questionBody ?? 'Question Body',
                        style: Theme.of(context).textTheme.headlineLarge),
                  ),
                ),
              ),
              SizedBox(
                  height: answersHeight,
                  width: max(constraints.maxWidth * 0.5, 150),
                  child: Column(
                    spacing: 10,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _controller, // Use the controller
                          autocorrect: false,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Answer',
                          ),
                          onChanged: (value) {
                            if (widget.allowTraversal) {
                              widget.onAnswer(widget.question, value);
                            }
                          },
                          onSubmitted: (value) {
                            widget.onAnswer(widget.question, value);
                          },
                        ),
                      ),
                      if (!widget.allowTraversal)
                        ElevatedButton(
                            onPressed: () {
                              widget.onAnswer(
                                  widget.question, _controller.text);
                            },
                            child: Text("Submit")),
                    ],
                  )),
            ],
          ),
        );
      },
    );
  }
}
