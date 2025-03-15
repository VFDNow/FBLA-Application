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
        return userAnswer == question['correctAnswer'];
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

    // ignore: prefer_typing_uninitialized_variables
    var answer;
    switch (_getQuestionType(question["questionType"] as String)) {
      case QuestionType.multipleChoice:
        answer = _getAnswer(question, userAnswer);
        break;
      case QuestionType.trueFalse:
        answer = userAnswer;
        break;
      case QuestionType.shortAnswer:
        answer = userAnswer;
        break;
      case QuestionType.longAnswer:
        answer = userAnswer;
        break;
    }

    var promptText = question.containsKey('correctAnswer') ||
            question.containsKey('criteria')
        ? '''
              Correct Answer or Criteria: "${question['correctAnswer'] ?? question['correctAnswers'] ?? question['criteria']}"
              User Answer: "$answer"
              
              Is the user's answer correct? Give leeway for typos. Respond with only "true" or "false".
            '''
        : '''
              Question title: "${question['questionTitle']}"
              Question body: "${question['questionBody']}"
              User answer: "$answer"
              
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

  Map<String, dynamic> _getAnswer(Map<String, dynamic> question, int answerId) {
    final answers = question['answers'] as List;
    return answers.firstWhere((answer) => answer['answerId'] == answerId);
  }

  int getStarValue(List<dynamic> questions, List<bool> scores) {
    int starValue = 0;
    for (int i = 0; i < questions.length; i++) {
      if (scores[i]) {
        if (questions[i]['starValue'] == null) {
          starValue += 10;
        } else {
          starValue += questions[i]['starValue'] as int;
        }
      }
    }
    return starValue;
  }
}

enum QuestionType { multipleChoice, trueFalse, shortAnswer, longAnswer }
