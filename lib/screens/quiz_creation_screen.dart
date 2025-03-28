import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fbla_application/utils/constants.dart';

class QuizCreationArgs {
  final String? classId;
  final List<String>? sectionIds;
  final String? existingQuizPath; // If editing an existing quiz

  QuizCreationArgs({this.classId, this.sectionIds, this.existingQuizPath});
}

class QuizCreationScreen extends StatefulWidget {
  const QuizCreationScreen({Key? key}) : super(key: key);

  @override
  _QuizCreationScreenState createState() => _QuizCreationScreenState();
}

class _QuizCreationScreenState extends State<QuizCreationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = false;
  String? username;

  // Quiz data model
  Map<String, dynamic> quizData = {
    'quizName': '',
    'quizDesc': '',
    'shuffleOrder': true,
    'allowTraversal': true,
    'authors': [],
    'questions': [],
  };

  // For managing questions
  List<Map<String, dynamic>> questions = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsername();

    // Initialize quiz data without global AI flag
    quizData = {
      'quizName': '',
      'quizDesc': '',
      'shuffleOrder': true,
      'allowTraversal': true,
      'authors': [],
      'questions': [],
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as QuizCreationArgs?;
    
    // Set class ID if provided
    if (args?.classId != null) {
      quizData['classId'] = args!.classId;
    }
    
    // Load existing quiz if editing
    if (args?.existingQuizPath != null) {
      _loadExistingQuiz(args!.existingQuizPath!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userData.exists) {
        final data = userData.data();
        if (data != null && data.containsKey('name')) {
          setState(() {
            username = data['name'];
            if (!quizData['authors'].contains(username) && username != null) {
              quizData['authors'] = [username!];
            }
          });
        }
      }
    }
  }

  Future<void> _loadExistingQuiz(String quizPath) async {
    setState(() {
      isLoading = true;
    });

    try {
      final quizRef = FirebaseStorage.instance.ref().child('quizzes/$quizPath.json');
      final quizBytes = await quizRef.getData();
      
      if (quizBytes != null) {
        final quizJson = utf8.decode(quizBytes);
        final loadedQuizData = json.decode(quizJson);
        
        setState(() {
          quizData = loadedQuizData;
          questions = List<Map<String, dynamic>>.from(quizData['questions'] ?? []);
        });
      }
    } catch (e) {
      _showSnackBar('Error loading quiz: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _addQuestion(String questionType) {
    final newQuestion = _createEmptyQuestion(questionType);
    setState(() {
      questions.add(newQuestion);
    });
  }

  Map<String, dynamic> _createEmptyQuestion(String questionType) {
    final questionId = questions.length.toString();
    
    // Base question structure
    final Map<String, dynamic> question = {
      'questionId': questionId,
      'questionType': questionType,
      'questionTitle': '',
      'questionBody': '',
    };
    
    // Add type-specific fields
    switch (questionType) {
      case 'MC':
        question['answers'] = [
          {'answerId': 0, 'answerBody': '', 'answerIcon': null},
          {'answerId': 1, 'answerBody': '', 'answerIcon': null}
        ];
        question['correctAnswers'] = [];
        break;
        
      case 'TF':
        question['correctAnswer'] = true;
        break;
        
      case 'SA':
        question['answers'] = [];
        question['singleWord'] = true;
        break;
        
      case 'LA':
        question['criteria'] = '';
        break;
    }
    
    return question;
  }

  void _removeQuestion(int index) {
    setState(() {
      questions.removeAt(index);
      // Update questionIds to maintain order
      for (int i = 0; i < questions.length; i++) {
        questions[i]['questionId'] = i.toString();
      }
    });
  }
  
  void _moveQuestion(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= questions.length) return;
    
    setState(() {
      final item = questions.removeAt(oldIndex);
      questions.insert(newIndex, item);
      
      // Update questionIds to maintain order
      for (int i = 0; i < questions.length; i++) {
        questions[i]['questionId'] = i.toString();
      }
    });
  }

  // Helper method to generate a unique ID without using uuid package
  String _generateUniqueId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Generate a random string of 10 characters
    String randomString = '';
    for (int i = 0; i < 10; i++) {
      randomString += chars[random.nextInt(chars.length)];
    }
    
    // Combine timestamp and random string for uniqueness
    return 'quiz_${timestamp}_$randomString';
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors before saving');
      return;
    }
    
    _formKey.currentState!.save();
    
    setState(() {
      isLoading = true;
    });
    
    try {
      // Update the questions in the quiz data
      quizData['questions'] = questions;
      
      // Generate quiz path if not exists
      final quizPath = quizData['quizPath'] ?? _generateUniqueId();
      quizData['quizPath'] = quizPath;
      
      // Convert to JSON and upload to Firebase Storage
      final quizJson = json.encode(quizData);
      final quizBytes = utf8.encode(quizJson);
      
      await FirebaseStorage.instance
        .ref()
        .child('quizzes/$quizPath.json')
        .putData(Uint8List.fromList(quizBytes));
      
      _showSnackBar('Quiz saved successfully!');
      
      // Navigate back or to assignment creation
      Navigator.pop(context, quizPath);
    } catch (e) {
      _showSnackBar('Error saving quiz: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  // Updated helper method to determine if AI grading is being used, based on answers
  bool _isUsingAIGrading(Map<String, dynamic> question) {
    // For long answer questions, always use AI grading
    if (question['questionType'] == 'LA') {
      return true;
    } 
    // Short answer questions ALWAYS use AI grading now
    else if (question['questionType'] == 'SA') {
      return true;
    }
    else if (question['questionType'] == 'MC') {
      return question['correctAnswers'] == null || question['correctAnswers'].isEmpty;
    } 
    else if (question['questionType'] == 'TF') {
      return question['correctAnswer'] == null;
    }
    return false;
  }

  // Updated AI chip to be an indicator
  Widget _buildAIGradingChip(Map<String, dynamic> question) {
    bool isLongAnswer = question['questionType'] == 'LA';
    bool isShortAnswer = question['questionType'] == 'SA';
    bool useAIGrading = _isUsingAIGrading(question);
    
    String chipLabel;
    if (isLongAnswer) {
      chipLabel = 'Always AI Graded';
    } else if (isShortAnswer) {
      chipLabel = 'AI Graded';
    } else if (useAIGrading) {
      chipLabel = 'Will use AI Grading';
    } else {
      chipLabel = 'Has Manual Answers';
    }
    
    return Chip(
      avatar: Icon(
        Icons.auto_awesome,
        color: useAIGrading ? Colors.purple : Colors.grey,
        size: 18,
      ),
      label: Text(
        chipLabel,
        style: TextStyle(
          color: useAIGrading ? Colors.purple[700] : Colors.grey[700],
        ),
      ),
      backgroundColor: useAIGrading ? Colors.purple[50] : Colors.grey[100],
      side: BorderSide(
        color: useAIGrading ? Colors.purple : Colors.grey,
        width: 1,
      ),
    );
  }

  // Short answer fields - updated to always show AI grading info and guidance for acceptable answers
  Widget _buildShortAnswerFields(Map<String, dynamic> question) {
    List<dynamic> answers = question['answers'] ?? [];
    bool singleWord = question['singleWord'] ?? true;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Answer Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // AI status indicator chip
            _buildAIGradingChip(question),
          ],
        ),
        
        // Single Word chip on its own row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: FilterChip(
            showCheckmark: false,
            label: Text('Single Word'),
            selected: singleWord,
            selectedColor: Colors.blue[100],
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: singleWord ? Colors.blue : Colors.grey,
                width: 1,
              ),
            ),
            labelStyle: TextStyle(
              color: singleWord ? Colors.blue[700] : Colors.grey[700],
            ),
            onSelected: (bool selected) {
              setState(() {
                question['singleWord'] = selected;
              });
            },
          ),
        ),
        
        // AI Grading info message - always shown for short answer
        Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.purple),
                  SizedBox(width: 8),
                  Text(
                    'AI-Powered Grading',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Short answer questions are graded by AI. Gemini will evaluate responses based on semantic meaning rather than exact matches.',
              ),
            ],
          ),
        ),
        
        SizedBox(height: 8),
        Divider(),
        Text('Example Answers (optional):', style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(height: 4),
        Text(
          'Providing examples helps fine-tune AI grading',
          style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
        ),
        SizedBox(height: 8),
        
        // List of acceptable answers - now labeled as examples
        ...answers.asMap().entries.map((entry) {
          final answerIndex = entry.key;
          final answerText = entry.value;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: answerText,
                    decoration: InputDecoration(
                      labelText: 'Example Answer ${answerIndex + 1}',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        answers[answerIndex] = value;
                        question['answers'] = answers;
                      });
                    },
                  ),
                ),
                
                // Delete answer button
                IconButton(
                  icon: Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() {
                      answers.removeAt(answerIndex);
                      question['answers'] = answers;
                    });
                  },
                ),
              ],
            ),
          );
        }).toList(),
        
        // Add answer button on its own row
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: TextButton.icon(
            icon: Icon(Icons.add_circle_outline),
            label: Text('Add Example Answer'),
            onPressed: () {
              setState(() {
                answers.add('');
                question['answers'] = answers;
              });
            },
          ),
        ),
      ],
    );
  }
  
  // Update Long Answer fields to use consistent FilterChip style for AI grading
  Widget _buildLongAnswerFields(Map<String, dynamic> question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Grading Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // Updated to use consistent FilterChip style
            Chip(
              avatar: Icon(
                Icons.auto_awesome,
                color: Colors.purple,
                size: 18,
              ),
              label: Text(
                'Always AI Graded',
                style: TextStyle(
                  color: Colors.purple[700],
                ),
              ),
              backgroundColor: Colors.purple[50],
              side: BorderSide(
                color: Colors.purple,
                width: 1,
              ),
            ),
          ],
        ),
        
        Divider(),
        
        // Grading criteria - optional but helpful for AI
        TextFormField(
          initialValue: question['criteria'] ?? '',
          decoration: InputDecoration(
            labelText: 'Grading Criteria (Optional)',
            hintText: 'Describe what a good answer should include...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          onChanged: (value) {
            setState(() {
              question['criteria'] = value;
            });
          },
        ),
        
        SizedBox(height: 16),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.purple),
                  SizedBox(width: 8),
                  Text(
                    'AI-Powered Grading',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Long answer questions are always graded by AI. If no criteria are provided, AI will automatically determine key concepts to look for in student responses.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Update answer preview to reflect automatic AI grading for SA and LA
  Widget _buildAnswerPreview(Map<String, dynamic> question) {
    final questionType = question['questionType'];
    
    // Show normal answer preview always
    switch (questionType) {
      case 'MC':
        List<dynamic> answers = question['answers'] ?? [];
        List<dynamic> correctAnswers = question['correctAnswers'] ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Answer Choices:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ...answers.asMap().entries.map((entry) {
              final answerIndex = entry.key;
              final answer = entry.value;
              final isCorrect = correctAnswers.contains(answer['answerId']);
              
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green[100] : null,
                  border: Border.all(
                    color: isCorrect ? Colors.green : Colors.grey,
                    width: isCorrect ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCorrect ? Colors.green : Colors.grey,
                        ),
                        color: isCorrect ? Colors.green : Colors.transparent,
                      ),
                      child: isCorrect 
                        ? Icon(Icons.check, size: 16, color: Colors.white) 
                        : null,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        answer['answerBody'].isNotEmpty
                            ? answer['answerBody']
                            : 'Option ${String.fromCharCode(65 + answerIndex)} (empty)',
                        style: TextStyle(
                          fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            
            // If AI grading is enabled, show a note
            if (_isUsingAIGrading(question)) 
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.purple.withOpacity(0.1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('AI will evaluate responses based on context and meaning', 
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.purple[700])),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
        
      case 'TF':
        final correctAnswer = question['correctAnswer'] ?? true;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Correct Answer:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: correctAnswer ? Colors.green[100] : null,
                    border: Border.all(
                      color: correctAnswer ? Colors.green : Colors.grey,
                      width: correctAnswer ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      correctAnswer 
                        ? Icon(Icons.check_circle, color: Colors.green) 
                        : Icon(Icons.circle_outlined, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'True',
                        style: TextStyle(
                          fontWeight: correctAnswer ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: !correctAnswer ? Colors.green[100] : null,
                    border: Border.all(
                      color: !correctAnswer ? Colors.green : Colors.grey,
                      width: !correctAnswer ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      !correctAnswer 
                        ? Icon(Icons.check_circle, color: Colors.green) 
                        : Icon(Icons.circle_outlined, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'False',
                        style: TextStyle(
                          fontWeight: !correctAnswer ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
        
      case 'SA':
        final answers = question['answers'] ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Graded Question:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            
            // Always show AI grading message
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.purple.withOpacity(0.1),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      answers.isEmpty 
                      ? 'AI will automatically grade responses based on semantics' 
                      : 'AI will evaluate responses using examples as a guide',
                      style: TextStyle(color: Colors.purple[700])
                    ),
                  ),
                ],
              ),
            ),
            
            // Show example answers if provided
            if (answers.isNotEmpty) ...[
              SizedBox(height: 12),
              Text('Example Answers:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ...answers.map((answer) => 
                Container(
                  margin: EdgeInsets.only(bottom: 4),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(child: Text(answer.toString())),
                    ],
                  ),
                )
              ).toList(),
            ],
          ],
        );
        
      case 'LA':
        final criteria = question['criteria'] ?? '';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Graded Question:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Only show criteria section if there's actual content
                  if (criteria.isNotEmpty) ...[
                    Text('Grading Criteria:', style: TextStyle(fontWeight: FontWeight.w500)),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[300]!),
                      ),
                      child: Text(criteria),
                    ),
                    SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          criteria.isEmpty 
                          ? 'AI will automatically grade responses based on semantics' 
                          : 'AI will grade based on these criteria',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      
      default:
        return Text('Unknown question type');
    }
  }

  // Add the missing Multiple Choice fields builder method
  Widget _buildMultipleChoiceFields(Map<String, dynamic> question, int index) {
    List<dynamic> answers = question['answers'] ?? [];
    List<dynamic> correctAnswers = question['correctAnswers'] ?? [];
    bool useAIGrading = _isUsingAIGrading(question);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Answer Choices',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // AI status indicator chip
            _buildAIGradingChip(question),
          ],
        ),
        
        SizedBox(height: 8),
        
        // List of answer choices
        ...answers.asMap().entries.map((entry) {
          final answerIndex = entry.key;
          final answer = entry.value;
          final isCorrect = correctAnswers.contains(answer['answerId']);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                // Correct answer checkbox
                Checkbox(
                  value: isCorrect,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        if (!correctAnswers.contains(answer['answerId'])) {
                          correctAnswers.add(answer['answerId']);
                        }
                      } else {
                        correctAnswers.remove(answer['answerId']);
                      }
                      question['correctAnswers'] = correctAnswers;
                    });
                  },
                ),
                
                // Answer text field
                Expanded(
                  child: TextFormField(
                    initialValue: answer['answerBody'],
                    decoration: InputDecoration(
                      labelText: 'Option ${String.fromCharCode(65 + answerIndex)}',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        answer['answerBody'] = value;
                      });
                    },
                  ),
                ),
                
                // Replace dropdown with icon selection button
                SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    _showIconSelectionDialog(answer);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: answer['answerIcon'] != null
                          ? Icon(Constants.questionIconStringMap[answer['answerIcon']], size: 24)
                          : Text('Icon', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ),
                  ),
                ),
                
                // Delete answer button
                IconButton(
                  icon: Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() {
                      final removedId = answer['answerId'];
                      answers.removeAt(answerIndex);
                      correctAnswers.remove(removedId);
                      question['answers'] = answers;
                      question['correctAnswers'] = correctAnswers;
                    });
                  },
                ),
              ],
            ),
          );
        }).toList(),
        
        // Add answer button
        TextButton.icon(
          icon: Icon(Icons.add_circle_outline),
          label: Text('Add Option'),
          onPressed: () {
            setState(() {
              final newAnswerId = answers.length;
              answers.add({
                'answerId': newAnswerId,
                'answerBody': '',
                'answerIcon': null, // Default to no icon
              });
              question['answers'] = answers;
            });
          },
        ),
      ],
    );
  }
  
  // Add a new method to show the icon selection dialog
  void _showIconSelectionDialog(Map<String, dynamic> answer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select an Icon'),
          content: Container(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: Constants.questionIconStringMap.length + 1, // +1 for "No icon" option
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "No icon" option
                  return InkWell(
                    onTap: () {
                      setState(() {
                        answer['answerIcon'] = null;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.do_not_disturb, color: Colors.grey),
                          Text('None', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }
                
                final iconIndex = index - 1; // Adjust for the "No icon" option
                final iconName = Constants.questionIconStringMap.keys.elementAt(iconIndex);
                final iconData = Constants.questionIconStringMap[iconName];
                
                return InkWell(
                  onTap: () {
                    setState(() {
                      answer['answerIcon'] = iconName;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: answer['answerIcon'] == iconName ? Colors.blue.shade100 : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(iconData, size: 24),
                        SizedBox(height: 4),
                        Text(
                          iconName,
                          style: TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Add the True/False fields builder method if it's missing too
  Widget _buildTrueFalseFields(Map<String, dynamic> question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Correct Answer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // AI status indicator chip
            _buildAIGradingChip(question),
          ],
        ),
        
        SizedBox(height: 8),
        
        // True/False radio buttons
        RadioListTile<bool>(
          title: Text('True'),
          value: true,
          groupValue: question['correctAnswer'],
          onChanged: (value) {
            setState(() {
              question['correctAnswer'] = value;
            });
          },
        ),
        
        RadioListTile<bool>(
          title: Text('False'),
          value: false,
          groupValue: question['correctAnswer'],
          onChanged: (value) {
            setState(() {
              question['correctAnswer'] = value;
            });
          },
        ),
        
        // Clear answer button to enable AI grading
        TextButton.icon(
          icon: Icon(Icons.auto_awesome),
          label: Text('Clear Answer for AI Grading'),
          onPressed: () {
            setState(() {
              question['correctAnswer'] = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildQuestionPreview(Map<String, dynamic> question) {
    final questionType = question['questionType'];
    final questionNumber = question['displayNumber'];
    final bool useAIGrading = _isUsingAIGrading(question);
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question title and number
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    questionNumber.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question['questionTitle'].isNotEmpty 
                        ? question['questionTitle'] 
                        : 'Untitled Question',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                
                // Show AI badge if applicable
                if (useAIGrading)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
                        SizedBox(width: 4),
                        Text(
                          'AI Graded',
                          style: TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Question body
            Text(
              question['questionBody'].isNotEmpty 
                  ? question['questionBody'] 
                  : 'No question text',
            ),
            
            Divider(),
            
            // Answer preview based on question type
            _buildAnswerPreview(question),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(quizData['quizName'].isNotEmpty 
            ? 'Edit: ${quizData['quizName']}' 
            : 'Create New Quiz'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            tooltip: 'Save Quiz',
            onPressed: _saveQuiz,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Edit"),
            Tab(text: "Preview"),
          ],
        ),
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildEditTab(),
              _buildPreviewTab(),
            ],
          ),
    );
  }

  Widget _buildEditTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quiz metadata
              _buildQuizMetadata(),
              
              SizedBox(height: 24),
              
              // Questions list
              _buildQuestionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizMetadata() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quiz Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            
            // Quiz name
            TextFormField(
              initialValue: quizData['quizName'],
              decoration: InputDecoration(
                labelText: 'Quiz Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a quiz name';
                }
                return null;
              },
              onSaved: (value) {
                quizData['quizName'] = value?.trim() ?? '';
              },
            ),
            
            SizedBox(height: 16),
            
            // Quiz description
            TextFormField(
              initialValue: quizData['quizDesc'],
              decoration: InputDecoration(
                labelText: 'Quiz Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              onSaved: (value) {
                quizData['quizDesc'] = value?.trim() ?? '';
              },
            ),
            
            SizedBox(height: 16),
            
            // Quiz settings - stacked vertically
            SwitchListTile(
              title: Text('Shuffle Questions'),
              subtitle: Text('Randomize question order for each student'),
              value: quizData['shuffleOrder'] ?? true,
              onChanged: (value) {
                setState(() {
                  quizData['shuffleOrder'] = value;
                });
              },
            ),
            
            SwitchListTile(
              title: Text('Allow Question Navigation'),
              subtitle: Text('Students can move back and forth between questions'),
              value: quizData['allowTraversal'] ?? true,
              onChanged: (value) {
                setState(() {
                  quizData['allowTraversal'] = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Questions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _buildAddQuestionButton(),
          ],
        ),
        
        SizedBox(height: 16),
        
        // Questions list
        questions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No questions yet. Add a question to get started!',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              )
            : ReorderableListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                onReorder: (oldIndex, newIndex) {
                  // Handle reordering logic
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  _moveQuestion(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final question = questions[index];
                  return _buildQuestionCard(question, index, key: ValueKey(question['questionId']));
                },
              ),
      ],
    );
  }

  Widget _buildAddQuestionButton() {
    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add),
          SizedBox(width: 4),
          Text('Add Question'),
        ],
      ),
      onSelected: _addQuestion,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'MC',
          child: ListTile(
            leading: Icon(Icons.radio_button_checked),
            title: Text('Multiple Choice'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'TF',
          child: ListTile(
            leading: Icon(Icons.check_box),
            title: Text('True/False'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'SA',
          child: ListTile(
            leading: Icon(Icons.short_text),
            title: Text('Short Answer'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'LA',
          child: ListTile(
            leading: Icon(Icons.text_fields),
            title: Text('Long Answer'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index, {required Key key}) {
    final questionType = question['questionType'];
    String questionTypeText = '';
    
    switch (questionType) {
      case 'MC': questionTypeText = 'Multiple Choice'; break;
      case 'TF': questionTypeText = 'True/False'; break;
      case 'SA': questionTypeText = 'Short Answer'; break;
      case 'LA': questionTypeText = 'Long Answer'; break;
      default: questionTypeText = 'Unknown Type';
    }
    
    return Card(
      key: key,
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        title: Text(question['questionTitle'].isNotEmpty 
            ? 'Q${index + 1}: ${question['questionTitle']}' 
            : 'Question ${index + 1}'),
        subtitle: Text(questionTypeText),
        leading: Icon(Icons.drag_handle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () => _removeQuestion(index),
            ),
            Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question title
                TextFormField(
                  initialValue: question['questionTitle'],
                  decoration: InputDecoration(
                    labelText: 'Question Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a question title';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      question['questionTitle'] = value;
                    });
                  },
                ),
                
                SizedBox(height: 16),
                
                // Question body
                TextFormField(
                  initialValue: question['questionBody'],
                  decoration: InputDecoration(
                    labelText: 'Question Text',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a question';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      question['questionBody'] = value;
                    });
                  },
                ),
                
                SizedBox(height: 16),
                
                // Question type specific fields
                _buildQuestionTypeFields(question, index),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTypeFields(Map<String, dynamic> question, int index) {
    final questionType = question['questionType'];
    
    switch (questionType) {
      case 'MC':
        return _buildMultipleChoiceFields(question, index);
      case 'TF':
        return _buildTrueFalseFields(question);
      case 'SA':
        return _buildShortAnswerFields(question);
      case 'LA':
        return _buildLongAnswerFields(question);
      default:
        return Text('Unknown question type');
    }
  }

  Widget _buildPreviewTab() {
    // Format questions for preview
    final formattedQuestions = questions.asMap().entries.map((entry) {
      final index = entry.key;
      final question = Map<String, dynamic>.from(entry.value);
      
      // Add question number for display
      question['displayNumber'] = index + 1;
      
      return question;
    }).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quiz title and description - using the form values
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quizData['quizName'].isEmpty ? 'Untitled Quiz' : quizData['quizName'],
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (quizData['quizDesc'].isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      quizData['quizDesc'],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  SizedBox(height: 16),
                  
                  // Quiz settings
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(
                          quizData['shuffleOrder'] == true 
                            ? Icons.shuffle 
                            : Icons.format_list_numbered,
                          size: 18,
                        ),
                        label: Text(
                          quizData['shuffleOrder'] == true 
                            ? 'Shuffled Questions' 
                            : 'Fixed Order'
                        ),
                      ),
                      Chip(
                        avatar: Icon(
                          quizData['allowTraversal'] == true 
                            ? Icons.swap_horiz 
                            : Icons.arrow_forward,
                          size: 18,
                        ),
                        label: Text(
                          quizData['allowTraversal'] == true 
                            ? 'Navigation Allowed' 
                            : 'One Direction'
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Questions preview
          Text(
            'Questions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          
          SizedBox(height: 16),
          
          formattedQuestions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No questions added yet',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              )
            : Column(
                children: formattedQuestions.map((question) => 
                  _buildQuestionPreview(question)
                ).toList(),
              ),
        ],
      ),
    );
  }
}
