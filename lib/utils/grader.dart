// File that grades quiz.json stuff
import 'package:firebase_vertexai/firebase_vertexai.dart';

class Grader {
  Grader();

  Future<List<bool>> gradeQuiz(
      Map<String, dynamic> quiz, Map<String, dynamic> userAnswers) async {
    var scores = <bool>[];

    for (var question in quiz['questions']) {
      var score = await gradeQuestion(question, userAnswers);
      scores.add(score);
    }

    return scores;
  }

  Future<bool> gradeQuestion(
      Map<String, dynamic> question, Map<String, dynamic> userAnswers) async {
    final questionId = question['questionId'] as String;
    if (!userAnswers.containsKey(questionId)) {
      return false;
    }

    final userAnswer = userAnswers[questionId];
    final questionType = _getQuestionType(question['questionType'] as String);

    // If no correct answer is provided, use AI to grade
    if (question['correctAnswer'] == null &&
        question['correctAnswers'] == null) {
      return await _gradeWithAi(question, userAnswer);
    }

    // If correct answer is provided, go based on question type

    switch (questionType) {
      case QuestionType.multipleChoice:
        if (question['correctAnswers'] != null) {
          return question['correctAnswers'].contains(userAnswer);
        } else {
          return userAnswer == question['correctAnswer'];
        }
      case QuestionType.trueFalse:
        return userAnswer == question['correctAnswer'] as String;
      case QuestionType.shortAnswer:
        // Use AI to grade short answer
        return await _gradeWithAi(question, userAnswer);
      case QuestionType.longAnswer:
        // Only AI is supported for long answer
        return await _gradeWithAi(question, userAnswer);
    }
  }

  Future<bool> _gradeWithAi(
      Map<String, dynamic> question, dynamic userAnswer) async {
    // Check if we have a correct answer to compare against
    var promptText = question.containsKey('correctAnswer')
        ? '''
              Correct Answer or Criteria: "${question['correctAnswer']}"
              User Answer: "$userAnswer"
              
              Is the user's answer correct? Give leeway for typos. Respond with only "true" or "false".
            '''
        : '''
              Question title: "${question['questionTitle']}"
              Question body: "${question['questionBody']}"
              User answer: "$userAnswer"
              
              Is the user's answer correct? Give leeway for typos. Respond with only "true" or "false".
            ''';

    // Initialize the Vertex AI service and the generative model
    final model =
        FirebaseVertexAI.instance.generativeModel(model: 'gemini-2.0-flash');
    final prompt = [Content.text(promptText)];

    // Decipher the response
    final response = await model.generateContent(prompt);

    return response.text != null &&
        response.text!.toLowerCase().contains('true');
  }

  QuestionType _getQuestionType(String type) {
    switch (type) {
      case 'MC':
        return QuestionType.multipleChoice;
      case 'TF':
        return QuestionType.trueFalse;
      case 'SA':
        return QuestionType.shortAnswer;
      case 'LA':
        return QuestionType.longAnswer;
      default:
        throw Exception('Unknown question type: $type');
    }
  }
}

enum QuestionType {
  multipleChoice,
  trueFalse,

  shortAnswer,
  longAnswer
}
