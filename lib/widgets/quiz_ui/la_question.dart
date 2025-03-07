import 'dart:math';

import 'package:flutter/material.dart';

class LaQuestion extends StatefulWidget {
  const LaQuestion(
      {super.key,
      required this.question,
      required this.onAnswer,
      this.allowTraversal = true});

  final Map<String, dynamic> question;
  final Function onAnswer;
  final bool allowTraversal;
  @override
  _LaQuestionState createState() => _LaQuestionState();
}

class _LaQuestionState extends State<LaQuestion> {
  @override
  Widget build(BuildContext context) {
    var questionBody = widget.question['questionBody'];
    var currentAnswer = "";

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
                  width: max(constraints.maxWidth * 0.8, 150),
                  child: Column(
                    spacing: 10,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          maxLines: 5,
                          minLines: 3,
                          autocorrect: false,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Answer',
                          ),
                          onChanged: (value) {
                            currentAnswer = value;
                          },
                          onSubmitted: (value) {
                            widget.onAnswer(widget.question, value);
                          },
                        ),
                      ),
                      if (!widget.allowTraversal)
                        ElevatedButton(
                            onPressed: () {
                              widget.onAnswer(widget.question, currentAnswer);
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
