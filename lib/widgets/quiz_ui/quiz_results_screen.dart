import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/utils/grader.dart';
import 'package:fbla_application/widgets/error_screen.dart';
import 'package:flutter/material.dart' hide ErrorWidget;

class QuizResultsArgs {
  final Map<String, dynamic> quiz;
  final List<bool> scores;

  QuizResultsArgs({required this.quiz, required this.scores});
}

class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final QuizResultsArgs args;
    try {
      args = ModalRoute.of(context)!.settings.arguments as QuizResultsArgs;
    } catch (error) {
      return Scaffold(
        body: ErrorWidget(errorMessage: "Error Loading Data"),
      );
    }

    final quiz = args.quiz;
    final scores = args.scores;

    final questionCount = quiz['questions'].length;
    final correctCount = scores.where((score) => score).length;
    final scorePercentage = (correctCount / questionCount) * 100;

    Color scoreColor;
    if (scorePercentage <= 20) {
      scoreColor = Constants.percentageColorMap["0-20"] ?? Colors.red;
    } else if (scorePercentage <= 40) {
      scoreColor = Constants.percentageColorMap["21-40"] ?? Colors.orange;
    } else if (scorePercentage <= 60) {
      scoreColor = Constants.percentageColorMap["41-60"] ?? Colors.yellow;
    } else if (scorePercentage <= 80) {
      scoreColor = Constants.percentageColorMap["61-80"] ?? Colors.lightGreen;
    } else {
      scoreColor = Constants.percentageColorMap["81-100"] ?? Colors.green;
    }

    return Scaffold(
      backgroundColor: scoreColor,
      appBar: AppBar(
        title: Text('Quiz Results'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Future.delayed(Duration(milliseconds: 100), () {
            Navigator.pop(context);
          });
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            // Center the content
            children: [
              Text('Quiz: ${quiz['quizName']}',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                height: 100,
                child: Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 50,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Center(
                              child: Text(
                                softWrap: false,
                                Grader()
                                    .getStarValue(quiz['questions'], scores)
                                    .toString(),
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
                              ),
                            ),
                          ),
                        ])),
              ),
              const SizedBox(height: 20),
              Text('Score: $correctCount / $questionCount',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text('${scorePercentage.toStringAsFixed(2)}%',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              Text('Click anywhere to return.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
