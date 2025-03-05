import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/widgets/quiz_ui/quiz_answer.dart';
import 'package:flutter/material.dart';

class TfQuestion extends StatefulWidget {
  const TfQuestion({super.key, required this.question});

  final Map<String, dynamic> question;
  @override
  _TFQuestionState createState() => _TFQuestionState();
}

class _TFQuestionState extends State<TfQuestion> {
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
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: QuizAnswer(
                          body: 'True',
                          iconName: "check",
                          color: Constants.quizColors[1],
                        ),
                      ),
                      Expanded(
                        child: QuizAnswer(
                          body: 'False',
                          iconName: "x",
                          color: Constants.quizColors[0],
                        ),
                      ),
                    ],
                  )),
            ],
          ),
        );
      },
    );
  }
}
