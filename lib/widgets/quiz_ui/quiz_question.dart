import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/widgets/quiz_ui/quiz_answer.dart';
import 'package:flutter/material.dart';

class QuizQuestion extends StatefulWidget {
  const QuizQuestion({super.key, required this.question});

  final Map<String, dynamic> question;
  @override
  _QuizQuestionState createState() => _QuizQuestionState();
}

class _QuizQuestionState extends State<QuizQuestion> {
  @override
  Widget build(BuildContext context) {
    var answers = widget.question['answers'] as List<dynamic>?;
    var questionTitle = widget.question['questionTitle'];
    var questionBody = widget.question['questionBody'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfHeight = constraints.maxHeight / 2;

        return Column(
          children: [
            Expanded(
              child: Center(
                child: Text(questionBody ?? 'Question Body',
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
            ),
            SizedBox(
              height: halfHeight,
              child: GridView.builder(
                padding: const EdgeInsets.all(20.0),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: (constraints.maxWidth / 2) /
                      (halfHeight /
                          (((answers?.length ?? 2.0) / 2.0).ceil() +
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
