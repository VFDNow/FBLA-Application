import 'package:fbla_application/widgets/quiz_ui/quiz_answer.dart';
import 'package:flutter/material.dart';

class QuizQuestion extends StatefulWidget {
  @override
  _QuizQuestionState createState() => _QuizQuestionState();
}

class _QuizQuestionState extends State<QuizQuestion> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfHeight = constraints.maxHeight / 2;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14.0),
              width: double.infinity,
              color: Theme.of(context).primaryColor,
              child: Center(
                child: Text(
                  "Question 1",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text("Question"),
              ),
            ),
            SizedBox(
              height: halfHeight,
              child: GridView.builder(
                padding: const EdgeInsets.all(20.0),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio:
                      (constraints.maxWidth / 2) / (halfHeight / 2.2),
                  mainAxisSpacing: 10.0,
                  crossAxisSpacing: 10.0,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
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
