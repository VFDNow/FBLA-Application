import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/widgets/quiz_ui/quiz_answer.dart';
import 'package:flutter/material.dart';

class SaQuestion extends StatefulWidget {
  const SaQuestion({super.key, required this.question, required this.onAnswer});

  final Map<String, dynamic> question;
  final Function onAnswer;
  @override
  _SaQuestionState createState() => _SaQuestionState();
}

class _SaQuestionState extends State<SaQuestion> {
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
                  width: double.infinity,
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            autocorrect: false,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Answer',
                              
                            ),
                            onChanged: (value) {
                              // widget.onAnswer(widget.question, value);
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                ),
            ],
          ),
        );
      },
    );
  }
}
