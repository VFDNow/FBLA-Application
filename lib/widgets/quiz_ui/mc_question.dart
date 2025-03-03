import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/widgets/quiz_ui/quiz_answer.dart';
import 'package:flutter/material.dart';

class MCQuestion extends StatefulWidget {
  const MCQuestion({super.key, required this.question});

  final Map<String, dynamic> question;
  @override
  _MCQuestionState createState() => _MCQuestionState();
}

class _MCQuestionState extends State<MCQuestion> {
  @override
  Widget build(BuildContext context) {
    var answers = widget.question['answers'] as List<dynamic>?;
    var questionTitle = widget.question['questionTitle'];
    var questionBody = widget.question['questionBody'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final answersHeight = constraints.maxHeight / 1.6;
        var crossAxisAmount = 2;
        if (answers == null) {
          crossAxisAmount == 1;
        }  else if (answers.length <= 1) {
          crossAxisAmount == 1;
        }
        if (constraints.maxWidth < 600) {
          crossAxisAmount = 1;
        }

        return Column(
          children: [
            Expanded(
              child: Center(
                child: Text(questionBody ?? 'Question Body',
                    style: Theme.of(context).textTheme.headlineLarge),
              ),
            ),
            SizedBox(
              height: answersHeight,
              child: GridView.builder(
                padding: const EdgeInsets.all(20.0),
                // physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisAmount,
                  childAspectRatio: (constraints.maxWidth / crossAxisAmount) /
                      (answersHeight /
                          (((answers?.length ?? 2.0) / crossAxisAmount).ceil() +
                              (answers?.length ?? 2.0) / 10)),
                  mainAxisSpacing: 10.0,
                  crossAxisSpacing: 10.0,
                ),
                itemCount: answers?.length ?? 2,
                itemBuilder: (context, index) {
                  var answerData = answers?[index];

                  if (answerData != null) {
                    var icon = answerData?["answerIcon"];
                    if (icon == null) {
                      var iconList =
                          Constants.questionIconStringMap.keys.toList();
                      icon = iconList[index % iconList.length];
                    }

                    return QuizAnswer(
                      body: answerData['answerBody'] ?? 'Answer ${index + 1}',
                      iconName: icon ?? 'star',
                      color: Constants.quizColors[index % Constants.quizColors.length],
                    );
                  }

                  return QuizAnswer(
                    body: 'Answer ${index + 1}',
                    iconName: 'star',
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
