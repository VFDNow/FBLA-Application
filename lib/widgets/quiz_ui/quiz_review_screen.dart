import 'package:flutter/material.dart';

class QuizReviewScreen extends StatelessWidget {
  const QuizReviewScreen(
      {super.key,
      required this.quizData,
      required this.answers,
      this.onSubmit});

  final Map<String, dynamic> quizData;
  final Map<String, dynamic> answers;
  final Function? onSubmit;

  bool _getAllQuestionsAnswered() {
    try {
      final questions = quizData["questions"];
      if (questions == null) return false;

      for (var question in questions) {
        if (question == null) continue;

        final questionId = question["questionId"];
        if (questionId == null) continue;

        if (!answers.containsKey(questionId)) {
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error checking questions answered: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              "Review Quiz",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 500,
                  height: 500,
                  child: Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: quizData["questions"].length,
                            itemBuilder: (context, index) {
                              return _buildQuestionCard(context, index);
                            },
                          ),
                        ),
                        Divider(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              _getAllQuestionsAnswered()
                                  ? "All Questions Answered"
                                  : "Not All Questions Answered",
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                      color: _getAllQuestionsAnswered()
                                          ? Colors.green
                                          : Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // print("Submitting...");
                onSubmit!(quizData);
              },
              child: const Text("Submit Quiz"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListTile(
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              (answers.containsKey(quizData["questions"][index]["questionId"])
                  ? Icons.check_circle
                  : Icons.cancel),
              color: (answers
                      .containsKey(quizData["questions"][index]["questionId"])
                  ? Colors.green
                  : Colors.red),
            ),
            Text(
                (answers.containsKey(quizData["questions"][index]["questionId"])
                    ? "Answered"
                    : "Unanswered")),
          ],
        ),
        title: Text(
          quizData["questions"][index]["questionTitle"],
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
