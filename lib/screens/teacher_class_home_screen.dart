import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fbla_application/screens/quiz_creation_screen.dart';

class TeacherClassHomeArgs {
  String className;
  List<String> sectionIds;
  String classIcon;
  String? baseClassId;

  TeacherClassHomeArgs(this.className, this.sectionIds, this.classIcon, {this.baseClassId});
}

class TeacherClassHomeScreen extends StatefulWidget {
  const TeacherClassHomeScreen({Key? key}) : super(key: key);

  @override
  _TeacherClassHomeScreenState createState() => _TeacherClassHomeScreenState();
}

class _TeacherClassHomeScreenState extends State<TeacherClassHomeScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> assignments = [];
  bool isLoading = true;
  late TeacherClassHomeArgs args;
  String? baseClassId;
  Map<String, dynamic>? baseClassData;
  late TabController _tabController;
  
  // Add scoped context reference for safe access
  BuildContext? _safeContext;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // Clear safe context reference first
    _safeContext = null;
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store context safely for later use
    _safeContext = context;
    args = ModalRoute.of(context)!.settings.arguments as TeacherClassHomeArgs;
    baseClassId = args.baseClassId;
    _loadSections();
    _loadAssignments();
  }

  Future<void> _loadSections() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Try to find the base class if not provided
      if (baseClassId == null) {
        // Look for a section to find the base class ID
        if (args.sectionIds.isNotEmpty) {
          DocumentSnapshot sectionDoc = await FirebaseFirestore.instance
              .collection('classes')
              .doc(args.sectionIds.first)
              .get();
          
          if (sectionDoc.exists) {
            Map<String, dynamic> data = sectionDoc.data() as Map<String, dynamic>;
            baseClassId = data['baseClassId'];
          }
        }
      }
      
      // Now load base class data if we have an ID
      if (baseClassId != null) {
        DocumentSnapshot baseClassDoc = await FirebaseFirestore.instance
            .collection('classTemplates')
            .doc(baseClassId)
            .get();
            
        if (baseClassDoc.exists) {
          baseClassData = baseClassDoc.data() as Map<String, dynamic>;
        }
      }

      List<Map<String, dynamic>> loadedSections = [];
      
      // Create a copy of the sectionIds list to avoid concurrent modification
      List<String> sectionIdsCopy = List.from(args.sectionIds);
      
      // Fetch data for each section
      for (String sectionId in sectionIdsCopy) {
        DocumentSnapshot sectionDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(sectionId)
            .get();
            
        if (sectionDoc.exists) {
          Map<String, dynamic> sectionData = sectionDoc.data() as Map<String, dynamic>;
          sectionData['classId'] = sectionId;
          
          // Check if this section has a join code
          QuerySnapshot joinCodeSnapshot = await FirebaseFirestore.instance
              .collection('invites')
              .where('classId', isEqualTo: sectionId)
              .limit(1)
              .get();
              
          if (joinCodeSnapshot.docs.isNotEmpty) {
            sectionData['joinCode'] = joinCodeSnapshot.docs.first.id;
          }
          
          // Get student count for this section
          List<dynamic> students = sectionData['students'] ?? [];
          sectionData['studentCount'] = students.length;
          
          loadedSections.add(sectionData);
        }
      }

      // Check if mounted before updating state
      if (mounted) {
        setState(() {
          sections = loadedSections;
          isLoading = false;
        });
      }
    } catch (e) {
      // Still handle errors even if not mounted
      print("Error loading sections: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAssignments() async {
    try {
      if (args.sectionIds.isEmpty) return;
      
      // Track unique assignments by ID for display in UI
      Map<String, Map<String, dynamic>> uniqueAssignments = {};
      Map<String, List<String>> assignmentSectionMap = {};
      Map<String, Map<String, dynamic>> assignmentResults = {};
      
      // Load assignments from all sections
      for (String sectionId in args.sectionIds) {
        DocumentSnapshot sectionDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(sectionId)
            .get();
        
        if (!sectionDoc.exists) continue;
        
        Map<String, dynamic> sectionData = sectionDoc.data() as Map<String, dynamic>;
        List<dynamic> sectionAssignments = sectionData['assignments'] ?? [];
        
        // Get section hour for display
        String sectionHour = sectionData['classHour'] ?? 'Unknown';
        
        // Process each assignment in this section
        for (var assignment in sectionAssignments) {
          String assignmentId = assignment['assignmentId'];
          
          // Track which sections contain this assignment (for display purposes only)
          if (!assignmentSectionMap.containsKey(assignmentId)) {
            assignmentSectionMap[assignmentId] = [];
            uniqueAssignments[assignmentId] = assignment as Map<String, dynamic>;
            
            // Initialize results tracking for this assignment
            assignmentResults[assignmentId] = {
              'totalStudents': 0,
              'completedCount': 0, 
              'overallCorrect': 0,
              'overallTotal': 0,
              'sectionResults': <String, Map<String, dynamic>>{}
            };
          }
          
          assignmentSectionMap[assignmentId]?.add(sectionHour);
          
          // Initialize section results
          if (!assignmentResults[assignmentId]!['sectionResults'].containsKey(sectionHour)) {
            assignmentResults[assignmentId]!['sectionResults'][sectionHour] = {
              'correct': 0,
              'total': 0,
              'completed': 0,
              'studentCount': 0,
              'sectionId': sectionId // Store section ID for later use
            };
          }
          
          // Get student count directly from the students array in the class document
          List<dynamic> students = sectionData['students'] ?? [];
          int studentCount = students.length;
          
          // Update counts
          assignmentResults[assignmentId]!['totalStudents'] += studentCount;
          assignmentResults[assignmentId]!['sectionResults'][sectionHour]['studentCount'] = studentCount;
          
          // Load quiz results for this section and assignment
          try {
            QuerySnapshot resultsSnapshot = await FirebaseFirestore.instance
                .collection('classes')
                .doc(sectionId)
                .collection('quizHistory')
                .where('assignmentId', isEqualTo: assignmentId)
                .get();
            
            // Process each quiz result
            for (var resultDoc in resultsSnapshot.docs) {
              Map<String, dynamic> resultData = resultDoc.data() as Map<String, dynamic>;
              List<dynamic> results = resultData['results'] ?? [];
              
              if (results.isNotEmpty) {
                // Count correct answers
                int correct = results.where((result) => result == true).length;
                int total = results.length;
                
                // Update overall metrics
                assignmentResults[assignmentId]!['completedCount']++;
                assignmentResults[assignmentId]!['overallCorrect'] += correct;
                assignmentResults[assignmentId]!['overallTotal'] += total;
                
                // Update section-specific metrics
                Map<String, dynamic> sectionResult = assignmentResults[assignmentId]!['sectionResults'][sectionHour];
                sectionResult['completed']++;
                sectionResult['correct'] += correct;
                sectionResult['total'] += total;
              }
            }
          } catch (e) {
            print("Error loading quiz results for section $sectionId: $e");
          }
        }
      }
      
      // Preload quiz data for all unique assignments
      for (String assignmentId in uniqueAssignments.keys) {
        try {
          final assignment = uniqueAssignments[assignmentId]!;
          final quizPathRef = FirebaseStorage.instance
              .ref()
              .child("quizzes/${assignment['quizPath']}.json");
          
          final quizData = await quizPathRef.getData();
          if (quizData != null) {
            final quizJson = utf8.decode(quizData);
            final quiz = json.decode(quizJson);
            
            // Store preloaded quiz data in the assignment
            assignment['preloadedQuiz'] = quiz;
            
            // Preload question statistics
            Map<int, Map<String, dynamic>> questionStats = {};
            int totalAttempts = 0;
            
            // Initialize stats for each question
            if (quiz['questions'] != null && quiz['questions'] is List) {
              for (int i = 0; i < quiz['questions'].length; i++) {
                questionStats[i] = {
                  'correct': 0,
                  'attempts': 0,
                };
              }
            }
            
            // For each section, fetch quiz history for this assignment
            for (String sectionId in args.sectionIds) {
              try {
                // Get quiz history for this section and assignment
                QuerySnapshot resultsSnapshot = await FirebaseFirestore.instance
                    .collection('classes')
                    .doc(sectionId)
                    .collection('quizHistory')
                    .where('assignmentId', isEqualTo: assignmentId)
                    .get();
                
                // Process each quiz result
                for (var resultDoc in resultsSnapshot.docs) {
                  totalAttempts++;
                  Map<String, dynamic> resultData = resultDoc.data() as Map<String, dynamic>;
                  List<dynamic> results = resultData['results'] ?? [];
                  
                  // Count results for each question
                  for (int i = 0; i < results.length; i++) {
                    if (i < questionStats.length) {
                      questionStats[i]!['attempts']++;
                      if (results[i] == true) {
                        questionStats[i]!['correct']++;
                      }
                    }
                  }
                }
              } catch (e) {
                print("Error preloading quiz results for section $sectionId: $e");
              }
            }
            
            // Store preloaded question stats in the assignment
            assignment['questionStats'] = questionStats;
            assignment['hasResults'] = totalAttempts > 0;
          }
        } catch (e) {
          print("Error preloading quiz data for assignment ${assignmentId}: $e");
          // Continue even if preloading fails for an assignment
        }
      }
      
      // Convert to list for UI and attach section/results information
      List<Map<String, dynamic>> loadedAssignments = [];
      uniqueAssignments.forEach((assignmentId, assignmentData) {
        loadedAssignments.add({
          ...assignmentData,
          'displaySections': assignmentSectionMap[assignmentId] ?? [], // For display only
          'results': assignmentResults[assignmentId] ?? {},
        });
      });
      
      if (mounted) {
        setState(() {
          assignments = loadedAssignments;
        });
      }
    } catch (e) {
      print("Error loading assignments: $e");
    }
  }
  
  // Method to create an assignment
  Future<void> _createAssignment() async {
    // Variables for the form
    TextEditingController nameController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(Duration(days: 7)); // Default due date is one week from now
    TimeOfDay selectedTime = TimeOfDay.now(); // Default due time is current time
    
    // Show dialog to collect assignment details
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Format the selected date and time for display
            String formattedDate = DateFormat('EEE, MMM d, yyyy').format(selectedDate);
            String formattedTime = selectedTime.format(context);
            
            return AlertDialog(
              title: Text('Create Assignment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Assignment name field
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Assignment Name',
                        hintText: 'Enter a name for this assignment',
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Due date picker
                    ListTile(
                      title: Text('Due Date'),
                      subtitle: Text(formattedDate),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null && picked != selectedDate) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    
                    // Due time picker
                    ListTile(
                      title: Text('Due Time'),
                      subtitle: Text(formattedTime),
                      trailing: Icon(Icons.access_time),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null && picked != selectedTime) {
                          setState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                    ),
                    
                    SizedBox(height: 16),
                    Text('You must create a new quiz for this assignment.', 
                      style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validate assignment name
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Please enter an assignment name'))
                      );
                      return;
                    }
                    
                    // Close the dialog
                    Navigator.of(dialogContext).pop();
                    
                    // Navigate directly to quiz creation
                    final createdQuizPath = await Navigator.pushNamed(
                      context, 
                      Constants.quizCreationRoute,
                      arguments: QuizCreationArgs(
                        sectionIds: args.sectionIds,
                        classId: args.sectionIds.isNotEmpty ? args.sectionIds.first : null
                      ),
                    );
                    
                    // If a quiz was created successfully, continue with assignment creation
                    if (createdQuizPath != null) {
                      final dueDate = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      
                      // Show section selection dialog
                      _showSectionSelectionDialog(
                        nameController.text.trim(),
                        createdQuizPath.toString(),
                        dueDate,
                      );
                    }
                  },
                  child: Text('Create Quiz'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show dialog to select which sections to assign to
  Future<void> _showSectionSelectionDialog(String assignmentName, String quizPath, DateTime dueDate) async {
    // Create a map to track which sections are selected (all selected by default)
    Map<String, bool> selectedSections = {};
    
    for (var section in sections) {
      selectedSections[section['classId']] = true;
    }
    
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select Sections'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assign "$assignmentName" to:'),
                    SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sections.length,
                        itemBuilder: (context, index) {
                          final section = sections[index];
                          final sectionId = section['classId'] as String;
                          final sectionName = section['classHour'] ?? 'Section ${index + 1}';
                          
                          return CheckboxListTile(
                            title: Text(sectionName),
                            subtitle: Text('${section['studentCount'] ?? 0} students'),
                            value: selectedSections[sectionId] ?? false,
                            onChanged: (bool? value) {
                              setState(() {
                                selectedSections[sectionId] = value ?? false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    
                    // Create the assignment
                    await _finalizeAssignmentCreation(
                      assignmentName,
                      quizPath,
                      dueDate,
                      selectedSections,
                    );
                  },
                  child: Text('Create Assignment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Create the assignment in the selected sections
  Future<void> _finalizeAssignmentCreation(
    String assignmentName,
    String quizPath,
    DateTime dueDate,
    Map<String, bool> selectedSections,
  ) async {
    // Show loading indicator
    setState(() {
      isLoading = true;
    });
    
    try {
      // Generate a unique assignment ID
      final assignmentId = 'assignment_${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser?.uid ?? "unknown"}';
      
      // Create the assignment object
      final assignmentData = {
        'assignmentId': assignmentId,
        'assignmentName': assignmentName,
        'quizPath': quizPath,
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': Timestamp.now(), // Use regular Timestamp instead of FieldValue.serverTimestamp()
      };
      
      // Add the assignment to each selected section
      for (String sectionId in selectedSections.keys) {
        if (selectedSections[sectionId] == true) {
          await FirebaseFirestore.instance
              .collection('classes')
              .doc(sectionId)
              .update({
                'assignments': FieldValue.arrayUnion([assignmentData])
              });
        }
      }
      
      // Reload assignments
      await _loadAssignments();
      
      // Show success message
      _showSnackBar('Assignment created successfully!');
    } catch (e) {
      _showSnackBar('Error creating assignment: $e', backgroundColor: Theme.of(context).colorScheme.error);
    } finally {
      // Hide loading indicator
      setState(() {
        isLoading = false;
      });
    }
  }

  // Method to preview quiz - now uses preloaded data
  Future<void> _previewQuiz(Map<String, dynamic> assignment) async {
    // If we have preloaded quiz data, use it immediately
    if (assignment.containsKey('preloadedQuiz')) {
      showDialog(
        context: context,
        builder: (dialogContext) => QuizPreviewDialog(
          quiz: assignment['preloadedQuiz'],
          questionStats: assignment['questionStats'],
          hasResults: assignment['hasResults'] ?? false,
        ),
      );
      return;
    }
    
    // If not preloaded, load it on demand (fallback)
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      final quizPathRef = FirebaseStorage.instance
          .ref()
          .child("quizzes/${assignment['quizPath']}.json");
      
      final quizData = await quizPathRef.getData();
      if (quizData == null) {
        throw Exception("Failed to load quiz data");
      }
      
      final quizJson = utf8.decode(quizData);
      final quiz = json.decode(quizJson);
      
      // Now fetch quiz statistics for all sections
      Map<int, Map<String, dynamic>> questionStats = {};
      int totalAttempts = 0;
      
      // Initialize stats for each question
      if (quiz['questions'] != null && quiz['questions'] is List) {
        for (int i = 0; i < quiz['questions'].length; i++) {
          questionStats[i] = {
            'correct': 0,
            'attempts': 0,
          };
        }
      }
      
      // For each section, fetch quiz history for this assignment
      for (String sectionId in args.sectionIds) {
        try {
          // Get quiz history for this section and assignment
          QuerySnapshot resultsSnapshot = await FirebaseFirestore.instance
              .collection('classes')
              .doc(sectionId)
              .collection('quizHistory')
              .where('assignmentId', isEqualTo: assignment['assignmentId'])
              .get();
          
          // Process each quiz result
          for (var resultDoc in resultsSnapshot.docs) {
            totalAttempts++;
            Map<String, dynamic> resultData = resultDoc.data() as Map<String, dynamic>;
            List<dynamic> results = resultData['results'] ?? [];
            
            // Count results for each question
            for (int i = 0; i < results.length; i++) {
              if (i < questionStats.length) {
                questionStats[i]!['attempts']++;
                if (results[i] == true) {
                  questionStats[i]!['correct']++;
                }
              }
            }
          }
        } catch (e) {
          print("Error loading quiz results for section $sectionId: $e");
        }
      }
      
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
      });
      
      // Show the quiz preview dialog with statistics
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => QuizPreviewDialog(
            quiz: quiz,
            questionStats: questionStats,
            hasResults: totalAttempts > 0,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
      });
      
      _showSnackBar('Error loading quiz: $e');
    }
  }

  // Add a new section to this class
  Future<void> _addSection() async {
    TextEditingController sectionController = TextEditingController(text: 'Period ${sections.length + 1}');
    
    return showDialog(
      context: context,
      builder: (dialogContext) {  // Use dialog context
        return AlertDialog(
          title: Text('Add New Section'),
          content: TextField(
            controller: sectionController,
            decoration: InputDecoration(labelText: 'Section Name/Hour'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String sectionName = sectionController.text.trim();
                if (sectionName.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Section name cannot be empty'))
                  );
                  return;
                }
                
                // Check for duplicate section names
                bool isDuplicate = sections.any((section) => 
                  section['classHour'] != null && 
                  section['classHour'].toString().toLowerCase() == sectionName.toLowerCase()
                );
                
                if (isDuplicate) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'A section with this name already exists',
                        style: TextStyle(color: Theme.of(dialogContext).colorScheme.onError),
                      ),
                      backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    )
                  );
                  return;
                }
                
                Navigator.of(dialogContext).pop();
                
                // Pre-capture the scaffold messenger
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final successMessage = SnackBar(content: Text('New section added successfully!'));
                final errorColor = Theme.of(context).colorScheme.error;
                
                // Create a new section with the same class details
                String? userId = FirebaseAuth.instance.currentUser?.uid;
                
                try {
                  // If we have base class data, use it
                  if (baseClassData != null) {
                    DocumentReference newSection = await FirebaseFirestore.instance
                        .collection('classes')
                        .add({
                          'className': baseClassData!['className'],
                          'classDesc': baseClassData!['classDesc'],
                          'classIcon': baseClassData!['classIcon'],
                          'owner': userId,
                          'baseClassId': baseClassId,
                          'classHour': sectionController.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                    
                    // Add the new section ID and reload
                    args.sectionIds.add(newSection.id);
                    if (mounted) {
                      _loadSections();
                      scaffoldMessenger.showSnackBar(successMessage);
                    }
                  } else {
                    // We don't have base class data, use the first section as template
                    if (sections.isNotEmpty) {
                      Map<String, dynamic> template = sections.first;
                      
                      // Create base class template first if it doesn't exist
                      if (baseClassId == null) {
                        DocumentReference baseClassRef = await FirebaseFirestore.instance
                            .collection('classTemplates')
                            .add({
                              'className': args.className,
                              'classDesc': template['classDesc'] ?? '',
                              'classIcon': args.classIcon,
                              'owner': userId,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                        
                        baseClassId = baseClassRef.id;
                        
                        // Update all existing sections to reference the base class
                        for (var section in sections) {
                          await FirebaseFirestore.instance
                              .collection('classes')
                              .doc(section['classId'])
                              .update({'baseClassId': baseClassId});
                        }
                      }
                      
                      // Now create the new section
                      DocumentReference newSection = await FirebaseFirestore.instance
                          .collection('classes')
                          .add({
                            'className': args.className,
                            'classDesc': template['classDesc'] ?? '',
                            'classIcon': args.classIcon,
                            'owner': userId,
                            'baseClassId': baseClassId,
                            'classHour': sectionController.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      
                      // Add the new section ID and reload
                      args.sectionIds.add(newSection.id);
                      if (mounted) {
                        _loadSections();
                        scaffoldMessenger.showSnackBar(successMessage);
                      }
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error adding section: $e'),
                        backgroundColor: errorColor,
                      )
                    );
                  }
                }
              },
              child: Text('Add Section'),
            ),
          ],
        );
      }
    );
  }

  // Edit base class details (updates all sections)
  Future<void> _editClassDetails() async {
    if (baseClassData == null && sections.isEmpty) return;
    
    // Use base class data or data from first section
    Map<String, dynamic> data = baseClassData ?? sections.first;
    
    TextEditingController nameController = TextEditingController(text: data['className']);
    TextEditingController descController = TextEditingController(text: data['classDesc'] ?? '');
    String selectedIcon = data['classIcon'] ?? 'General';
    
    return showDialog(
      context: context,
      builder: (dialogContext) {  // Use the dialog's context, not the widget's context
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Class Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Class Name'),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: 'Class Description'),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedIcon,
                      decoration: InputDecoration(labelText: 'Class Subject'),
                      items: Constants.subjectIconStringMap.keys
                          .map((icon) => DropdownMenuItem(
                                child: Row(
                                  children: [
                                    Icon(Constants.subjectIconStringMap[icon]),
                                    SizedBox(width: 10),
                                    Text(icon),
                                  ],
                                ),
                                value: icon,
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedIcon = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    String newName = nameController.text.trim();
                    String newDesc = descController.text.trim();
                    
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Class name cannot be empty'))
                      );
                      return;
                    }
                    
                    Navigator.of(dialogContext).pop();
                    
                    // Pre-capture the scaffold messenger before async operations
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final successMessage = SnackBar(content: Text('Class details updated successfully!'));
                    final errorStyle = Theme.of(context).colorScheme.error;
                    
                    try {
                      // Update base class template if it exists
                      if (baseClassId != null) {
                        await FirebaseFirestore.instance
                            .collection('classTemplates')
                            .doc(baseClassId)
                            .update({
                              'className': newName,
                              'classDesc': newDesc,
                              'classIcon': selectedIcon,
                            });
                      }
                      
                      // Update all section classes
                      for (var section in sections) {
                        await FirebaseFirestore.instance
                            .collection('classes')
                            .doc(section['classId'])
                            .update({
                              'className': newName,
                              'classDesc': newDesc,
                              'classIcon': selectedIcon,
                            });
                      }
                      
                      // Update any existing join codes
                      for (var section in sections) {
                        if (section['joinCode'] != null) {
                          await FirebaseFirestore.instance
                              .collection('invites')
                              .doc(section['joinCode'])
                              .update({
                                'className': newName,
                                'classIcon': selectedIcon,
                              });
                        }
                      }
                      
                      // Update args for this screen
                      args.className = newName;
                      args.classIcon = selectedIcon;
                      
                      // Reload sections
                      if (mounted) {
                        _loadSections();
                        // Use pre-captured scaffold messenger
                        scaffoldMessenger.showSnackBar(successMessage);
                      }
                    } catch (e) {
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Error updating class: $e'),
                            backgroundColor: errorStyle,
                          )
                        );
                      }
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Method to assign an assignment to additional sections
  Future<void> _assignToMoreSections(Map<String, dynamic> assignment) async {
    // Early return if widget is disposed
    if (!mounted) return;
    
    // Get section IDs and hours for display
    Map<String, String> sectionHoursMap = {};
    
    // Find out which sections already have this assignment
    Set<String> assignedSectionIds = {};
    
    for (String sectionId in args.sectionIds) {
      DocumentSnapshot sectionDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(sectionId)
          .get();
      
      if (!sectionDoc.exists) continue;
      
      Map<String, dynamic> sectionData = sectionDoc.data() as Map<String, dynamic>;
      sectionHoursMap[sectionId] = sectionData['classHour'] ?? 'Unknown';
      
      List<dynamic> sectionAssignments = sectionData['assignments'] ?? [];
      bool hasAssignment = sectionAssignments.any(
        (a) => a['assignmentId'] == assignment['assignmentId']
      );
      
      if (hasAssignment) {
        assignedSectionIds.add(sectionId);
      }
    }
    
    // Create a list of sections that don't already have this assignment
    List<String> unassignedSectionIds = args.sectionIds
        .where((id) => !assignedSectionIds.contains(id))
        .toList();
    
    // Capture context before async operation
    final currentContext = context;
    
    // Check mounted state before showing UI
    if (!mounted) return;
    
    if (unassignedSectionIds.isEmpty) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text('Assignment is already assigned to all sections'))
      );
      return;
    }
    
    // Show dialog to select sections
    if (mounted) {
      await showDialog(
        context: currentContext,
        builder: (dialogContext) => AssignmentSectionDialog(
          assignment: assignment,
          unassignedSectionIds: unassignedSectionIds,
          sectionHoursMap: sectionHoursMap,
          onAssign: (selectedSectionIds) async {
            if (selectedSectionIds.isEmpty) return;
            
            // Check if still mounted before showing loading
            if (!mounted) return;
            
            setState(() {
              isLoading = true;
            });
            
            try {
              // Copy assignment to each selected section
              for (String sectionId in selectedSectionIds) {
                // Create a clean copy of the assignment data to add to the other section
                Map<String, dynamic> assignmentCopy = {
                  'assignmentId': assignment['assignmentId'],
                  'assignmentName': assignment['assignmentName'],
                  'quizPath': assignment['quizPath'],
                  'dueDate': assignment['dueDate'],
                  // Add other necessary fields, but NOT any section-specific data
                };
                
                await FirebaseFirestore.instance
                    .collection('classes')
                    .doc(sectionId)
                    .update({
                      'assignments': FieldValue.arrayUnion([assignmentCopy])
                    });
              }
              
              // Reload assignments to update the UI
              await _loadAssignments();
              
              if (mounted) {
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  SnackBar(content: Text('Assignment assigned to selected sections'))
                );
              }
            } catch (e) {
              print("Error assigning to sections: $e");
              if (mounted) {
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  SnackBar(
                    content: Text('Error assigning to sections: $e'),
                    backgroundColor: Theme.of(currentContext).colorScheme.error,
                  )
                );
              }
            } finally {
              if (mounted) {
                setState(() {
                  isLoading = false;
                });
              }
            }
          },
        )
      );
    }
  }

  // Helper method for showing snackbars safely
  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(args.className),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: 'Edit Class',
            onPressed: _editClassDetails,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Class Sections"),
            Tab(text: "Assignments"),
          ],
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (mounted) {
                  await _loadSections();
                  await _loadAssignments();
                }
                return;
              },
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Sections Tab
                  _buildSectionsTab(),
                  
                  // Assignments Tab
                  _buildAssignmentsTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildClassHeader() {
    return           Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Constants.subjectIconStringMap[args.classIcon] ?? Icons.book,
                    size: 48,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          args.className,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${sections.length} ${sections.length == 1 ? 'Section' : 'Sections'}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (sections.isNotEmpty && sections.first['classDesc'] != null && sections.first['classDesc'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              sections.first['classDesc'],
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }
  
  Widget _buildSectionsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class header
          _buildClassHeader(),

          SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Class Sections',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Add Section'),
                onPressed: _addSection,
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // List sections
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                child: ExpansionTile(
                  title: Text(section['classHour'] ?? 'N/A'),
                  subtitle: Text('${section['studentCount'] ?? 0} students'),
                  leading: Icon(Icons.class_),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (section['classDesc'] != null && section['classDesc'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                section['classDesc'],
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          
                          // Join Code section - display only
                          Card(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Join Code', 
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  SizedBox(height: 8),
                                  if (section['joinCode'] != null)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          section['joinCode'],
                                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.copy),
                                          onPressed: () {
                                            // Pre-capture the ScaffoldMessenger before any async operations
                                            final scaffoldMsgr = ScaffoldMessenger.of(context);
                                            final msg = Text('Join code copied to clipboard');
                                            
                                            // Then use the clipboard without awaiting in this callback
                                            Clipboard.setData(ClipboardData(text: section['joinCode']));
                                            scaffoldMsgr.showSnackBar(SnackBar(content: msg));
                                          },
                                        ),
                                      ],
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Join code is being generated...',
                                              style: TextStyle(fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        TextButton.icon(
                                          icon: Icon(Icons.refresh),
                                          label: Text('Refresh'),
                                          onPressed: () {
                                            // Reload sections to check if join code is available
                                            _loadSections(); 
                                            
                                            // Show feedback to the user
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Checking for join code...'))
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Section actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: Icon(Icons.edit),
                                label: Text('Manage'),
                                onPressed: () {
                                  // Navigate to the regular class page for this specific section
                                  Navigator.pushNamed(
                                    context,
                                    Constants.classHomeRoute,
                                    arguments: ClassHomeArgs(section['classId'])
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildAssignmentsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assignments',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Create Assignment'),
                onPressed: _createAssignment,
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // List assignments
          if (assignments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No assignments yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                final assignment = assignments[index];
                final List<String> displaySections = 
                    List<String>.from(assignment['displaySections'] ?? []);
                
                // Check if assignment is already assigned to all sections
                final bool assignedToAllSections = displaySections.length >= sections.length;
                
                // Get results data
                final Map<String, dynamic> results = assignment['results'] ?? {};
                final int totalStudents = results['totalStudents'] ?? 0;
                final int completedCount = results['completedCount'] ?? 0;
                final int overallCorrect = results['overallCorrect'] ?? 0;
                final int overallTotal = results['overallTotal'] ?? 0;
                
                // Calculate overall completion rate and score
                final double completionRate = totalStudents > 0 ? completedCount / totalStudents : 0;
                final double overallScore = overallTotal > 0 ? overallCorrect / overallTotal : 0;
                
                // Section results
                final Map<String, dynamic> sectionResults = 
                    results['sectionResults'] ?? <String, Map<String, dynamic>>{};
                
                return InkWell(
                  onTap: () => _previewQuiz(assignment),
                  child: Card(
                    margin: EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Icon(Icons.assignment),
                          title: Text(assignment['assignmentName'] ?? 'Unnamed Assignment'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (assignment['dueDate'] != null)
                                Text('Due: ${DateFormat('EEE, MMM. d, h:mm a').format((assignment['dueDate'] as Timestamp).toDate())}'),
                            ],
                          ),
                        ),
                        
                        // Results Section if there are any
                        if (completedCount > 0) 
                          _buildResultsSection(overallScore, completionRate, sectionResults),
                        
                        // No Results Message if needed
                        if (completedCount == 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Text(
                              'No quiz results available yet',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                        
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Assigned to:', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  for (var section in displaySections)
                                    Chip(
                                      label: Text(section),
                                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Only show button if there are sections left to assign to
                                  if (!assignedToAllSections)
                                    TextButton.icon(
                                      icon: Icon(Icons.add_circle_outline),
                                      label: Text('Assign to More Sections'),
                                      onPressed: () => _assignToMoreSections(assignment),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Helper method to build the results section for each assignment
  Widget _buildResultsSection(double overallScore, double completionRate, Map<String, dynamic> sectionResults) {
    // Color for overall score (green to red) based on percentage
    Color getScoreColor(double score) {
      if (score >= 0.9) return Colors.green;
      if (score >= 0.8) return Colors.green[600]!;
      if (score >= 0.7) return Colors.lime;
      if (score >= 0.6) return Colors.yellow[700]!;
      if (score >= 0.5) return Colors.orange;
      return Colors.red;
    }
    
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Results', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  Icon(Icons.people, size: 14),
                  SizedBox(width: 4),
                  Text('${(completionRate * 100).toStringAsFixed(0)}% completion',
                    style: TextStyle(fontSize: 13),
                  )
                ],
              )
            ],
          ),
          
          SizedBox(height: 8),
          
          // Overall progress bar for completion rate
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completionRate,
              backgroundColor: Colors.grey[200],
              minHeight: 8.0, // Change from int to double
            ),
          ),
          
          SizedBox(height: 12),
          
          // Overall score
          Row(
            children: [
              Text('Overall: ', style: TextStyle(fontWeight: FontWeight.w500)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getScoreColor(overallScore).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: getScoreColor(overallScore)),
                ),
                child: Text(
                  '${(overallScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: getScoreColor(overallScore),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Section breakdown
          if (sectionResults.isNotEmpty) ...[
            Text('Section Breakdown:', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Column(
              children: sectionResults.entries.map((entry) {
                final sectionHour = entry.key;
                final data = entry.value;
                
                final completed = data['completed'] ?? 0;
                final studentCount = data['studentCount'] ?? 0;
                final correct = data['correct'] ?? 0;
                final total = data['total'] ?? 0;
                
                final sectionScore = total > 0 ? correct / total : 0.0;
                final sectionCompletionRate = studentCount > 0 ? (completed / studentCount).toDouble() : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(sectionHour),
                      ),
                      Expanded(
                        flex: 4,
                        child: Stack(
                          children: [
                            // Background
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: sectionCompletionRate,
                                backgroundColor: Colors.grey[200],
                                minHeight: 20.0, // Change from int to double
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey[300]!
                                ),
                              ),
                            ),
                            // Score text
                            Container(
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                '${(sectionScore * 100).toStringAsFixed(0)}% (${completed}/${studentCount})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 40,
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: getScoreColor(sectionScore).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: getScoreColor(sectionScore)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${(sectionScore * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: getScoreColor(sectionScore),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// Add a new QuizPreviewDialog widget
class QuizPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> quiz;
  final Map<int, Map<String, dynamic>>? questionStats;
  final bool hasResults;
  
  const QuizPreviewDialog({
    Key? key, 
    required this.quiz, 
    this.questionStats, 
    this.hasResults = false
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              quiz['quizName'] ?? 'Quiz Preview',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 8),
            Text(
              quiz['quizDesc'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: (quiz['questions'] as List?)?.length ?? 0,
                itemBuilder: (context, index) {
                  final question = quiz['questions'][index];
                  final stats = questionStats?[index];
                  return _buildQuestionCard(context, question, index, stats);
                },
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, Map<String, dynamic> question, int index, Map<String, dynamic>? stats) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Q${index + 1}: ${question['questionTitle'] ?? 'Question'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // Show question stats if available
                if (hasResults && stats != null)
                  _buildQuestionStatsBadge(context, stats),
              ],
            ),
            SizedBox(height: 4),
            Text(
              question['questionBody'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 8),
            Divider(),
            SizedBox(height: 8),
            
            // Render different answer types based on question type
            if (question['questionType'] == 'MC')
              _buildMultipleChoiceAnswers(context, question)
            else if (question['questionType'] == 'TF')
              _buildTrueFalseAnswers(context, question)
            else if (question['questionType'] == 'SA')
              _buildShortAnswers(context, question)
            else if (question['questionType'] == 'LA')
              _buildLongAnswer(context, question)
            else
              _buildAIGradedMessage(context),
          ],
        ),
      ),
    );
  }

  // New method to display question statistics
  Widget _buildQuestionStatsBadge(BuildContext context, Map<String, dynamic> stats) {
    final int correct = stats['correct'] ?? 0;
    final int attempts = stats['attempts'] ?? 0;
    final double successRate = attempts > 0 ? correct / attempts : 0;
    
    // Color for score (green to red) based on percentage - same as in _buildResultsSection
    Color getScoreColor(double score) {
      if (score >= 0.9) return Colors.green;
      if (score >= 0.8) return Colors.green[600]!;
      if (score >= 0.7) return Colors.lime;
      if (score >= 0.6) return Colors.yellow[700]!;
      if (score >= 0.5) return Colors.orange;
      return Colors.red;
    }
    
    final scoreColor = getScoreColor(successRate);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scoreColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics, size: 16, color: scoreColor),
          SizedBox(width: 4),
          Text(
            '${(successRate * 100).toStringAsFixed(0)}% correct',
            style: TextStyle(
              color: scoreColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  // Add new method for short answers
  Widget _buildShortAnswers(BuildContext context, Map<String, dynamic> question) {
    final List<dynamic>? answers = question['answers'];
    final String? criteria = question['criteria'];
    
    if (answers != null && answers.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Acceptable Answers:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(child: Text(answer.toString())),
                ],
              ),
            )
          ).toList(),
        ],
      );
    } else if (criteria != null && criteria.isNotEmpty) {
      return _buildCriteriaSection(context, criteria);
    } else {
      return _buildAIGradedMessage(context);
    }
  }
  
  // Add new method for long answers
  Widget _buildLongAnswer(BuildContext context, Map<String, dynamic> question) {
    final String? criteria = question['criteria'];
    
    if (criteria != null && criteria.isNotEmpty) {
      return _buildCriteriaSection(context, criteria);
    } else {
      return _buildAIGradedMessage(context);
    }
  }
  
  // Helper method for showing criteria
  Widget _buildCriteriaSection(BuildContext context, String criteria) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grading Criteria:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[300]!),
          ),
          child: Text(criteria),
        ),
      ],
    );
  }
  
  // Helper method for AI graded message
  Widget _buildAIGradedMessage(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome, // Gemini-like icon (sparkle)
            color: Colors.purple,
            size: 28,
          ),
          SizedBox(width: 12),
          Text(
            'Graded by AI',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.purple[700],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMultipleChoiceAnswers(BuildContext context, Map<String, dynamic> question) {
    final List correctAnswers = question['correctAnswers'] ?? [];
    final List answers = question['answers'] ?? [];
    
    // If no correct answers defined, show AI graded message
    if (correctAnswers.isEmpty) {
      return _buildAIGradedMessage(context);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < answers.length; i++)
          Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: correctAnswers.contains(answers[i]['answerId']) 
                  ? Colors.green[100]
                  : null,
              border: Border.all(
                color: correctAnswers.contains(answers[i]['answerId'])
                  ? Colors.green
                  : Colors.grey,
                width: correctAnswers.contains(answers[i]['answerId']) ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  correctAnswers.contains(answers[i]['answerId']) 
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: correctAnswers.contains(answers[i]['answerId'])
                      ? Colors.green
                      : Colors.grey,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(answers[i]['answerBody'] ?? 'Answer ${i + 1}'),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildTrueFalseAnswers(BuildContext context, Map<String, dynamic> question) {
    // Check if correctAnswer is actually defined
    if (!question.containsKey('correctAnswer')) {
      return _buildAIGradedMessage(context);
    }
    
    final bool correctAnswer = question['correctAnswer'] ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: correctAnswer ? Colors.green[100] : null,
            border: Border.all(
              color: correctAnswer ? Colors.green : Colors.grey,
              width: correctAnswer ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                correctAnswer ? Icons.check_circle : Icons.circle_outlined,
                color: correctAnswer ? Colors.green : Colors.grey,
              ),
              SizedBox(width: 8),
              Text('True'),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: !correctAnswer ? Colors.green[100] : null,
            border: Border.all(
              color: !correctAnswer ? Colors.green : Colors.grey,
              width: !correctAnswer ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                !correctAnswer ? Icons.check_circle : Icons.circle_outlined,
                color: !correctAnswer ? Colors.green : Colors.grey,
              ),
              SizedBox(width: 8),
              Text('False'),
            ],
          ),
        ),
      ],
    );
  }
}

// Add the AssignmentSectionDialog for selecting which sections to assign to
class AssignmentSectionDialog extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final List<String> unassignedSectionIds;
  final Map<String, String> sectionHoursMap;
  final Function(List<String>) onAssign;
  
  const AssignmentSectionDialog({
    Key? key,
    required this.assignment,
    required this.unassignedSectionIds,
    required this.sectionHoursMap,
    required this.onAssign,
  }) : super(key: key);
  
  @override
  _AssignmentSectionDialogState createState() => _AssignmentSectionDialogState();
}

class _AssignmentSectionDialogState extends State<AssignmentSectionDialog> {
  Set<String> selectedSectionIds = {};
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign to Additional Sections'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assignment: ${widget.assignment['assignmentName']}'),
            SizedBox(height: 16),
            Text('Select sections:'),
            SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.unassignedSectionIds.length,
                itemBuilder: (context, index) {
                  final sectionId = widget.unassignedSectionIds[index];
                  final sectionHour = widget.sectionHoursMap[sectionId] ?? 'Unknown';
                  
                  return CheckboxListTile(
                    title: Text(sectionHour),
                    value: selectedSectionIds.contains(sectionId),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          selectedSectionIds.add(sectionId);
                        } else {
                          selectedSectionIds.remove(sectionId);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onAssign(selectedSectionIds.toList());
          },
          child: Text('Assign'),
        ),
      ],
    );
  }
}
