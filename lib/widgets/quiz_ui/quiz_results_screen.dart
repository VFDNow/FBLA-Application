import 'package:flutter/material.dart';

class QuizResultsArgs {
  final Map<String, dynamic> quiz;
  final List<bool> scores;

  QuizResultsArgs({required this.quiz, required this.scores});
}

class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Results'),
      ),
      body: Center(
        child: Text(
          'Your Results',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
