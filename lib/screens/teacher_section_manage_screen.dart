import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart'; // Import for date formatting

class TeacherSectionManageArgs {
  final String sectionId;
  final String sectionName;
  final String className;
  final String classIcon;

  TeacherSectionManageArgs({
    required this.sectionId,
    required this.sectionName,
    required this.className,
    required this.classIcon,
  });
}

class TeacherSectionManageScreen extends StatefulWidget {
  const TeacherSectionManageScreen({Key? key}) : super(key: key);

  @override
  _TeacherSectionManageScreenState createState() => _TeacherSectionManageScreenState();
}

class _TeacherSectionManageScreenState extends State<TeacherSectionManageScreen> with SingleTickerProviderStateMixin {
  late TeacherSectionManageArgs args;
  bool isLoading = true;
  bool isLoadingPerformance = false;

  late TabController _tabController;

  List<Map<String, dynamic>> students = [];
  Map<String, Map<String, dynamic>> groups = {};
  Map<String, Map<String, dynamic>> studentPerformance = {};
  
  // Add a field to store section assignments for lookup
  List<Map<String, dynamic>> assignments = [];

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> filteredStudents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeArgs = ModalRoute.of(context)!.settings.arguments;
    if (routeArgs is! TeacherSectionManageArgs) {
      throw ArgumentError('TeacherSectionManageScreen requires TeacherSectionManageArgs');
    }
    args = routeArgs;
    _loadSectionData();
  }

  void _filterStudents() {
    final searchText = _searchController.text.toLowerCase();
    setState(() {
      filteredStudents = searchText.isEmpty
          ? students
          : students.where((student) {
              final name = '${student['userFirst']} ${student['userLast']}'.toLowerCase();
              return name.contains(searchText);
            }).toList();
    });
  }

  String findStudentGroup(String studentId) {
    for (String groupName in groups.keys) {
      List<dynamic> members = groups[groupName]?['members'] ?? [];
      if (members.any((member) => member['uId'] == studentId)) {
        return groupName;
      }
    }
    return 'None';
  }

  Future<void> _loadSectionData() async {
    setState(() {
      isLoading = true;
    });

    try {
      DocumentSnapshot sectionDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(args.sectionId)
          .get();

      if (sectionDoc.exists) {
        Map<String, dynamic> data = sectionDoc.data() as Map<String, dynamic>;

        // Load assignments from the section document
        List<dynamic> assignmentList = data['assignments'] ?? [];
        List<Map<String, dynamic>> loadedAssignments = [];
        
        for (var assignment in assignmentList) {
          if (assignment is Map<String, dynamic>) {
            loadedAssignments.add(assignment);
          }
        }

        List<dynamic> studentsList = data['students'] ?? [];
        List<Map<String, dynamic>> loadedStudents = [];

        for (var studentRef in studentsList) {
          try {
            String? studentId;

            if (studentRef is Map && studentRef['studentId'] != null) {
              studentId = studentRef['studentId'].toString();
            }

            if (studentId == null || studentId.isEmpty) {
              if (studentRef is Map &&
                  (studentRef['name'] != null ||
                   (studentRef['userFirst'] != null && studentRef['userLast'] != null))) {
                Map<String, dynamic> basicStudent = {
                  'id': 'unknown_${loadedStudents.length}',
                  'userFirst': studentRef['userFirst'] ?? studentRef['name']?.toString().split(' ').first ?? 'Unknown',
                  'userLast': studentRef['userLast'] ?? 
                    ((studentRef['name']?.toString().split(' ').length  ?? 0) > 1 
                      ? studentRef['name'].toString().split(' ').last 
                      : ''),
                  'imageSeed': 'default_seed',
                };
                loadedStudents.add(basicStudent);
              }
              continue;
            }

            DocumentSnapshot userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(studentId)
                .get();

            if (userDoc.exists) {
              Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
              userData['id'] = studentId;
              userData['imageSeed'] = userData['imageSeed'] ?? studentId;

              if (userData['userFirst'] == null || userData['userLast'] == null) {
                if (userData['name'] != null) {
                  List<String> nameParts = userData['name'].toString().split(' ');
                  userData['userFirst'] = nameParts.first;
                  userData['userLast'] = nameParts.length > 1 ? nameParts.last : '';
                } else {
                  userData['userFirst'] = userData['userFirst'] ?? 'Student';
                  userData['userLast'] = userData['userLast'] ?? 
                      (studentId != null && studentId.isNotEmpty 
                          ? studentId.substring(0, min(6, studentId.length)) 
                          : 'Unknown');
                }
              }

              loadedStudents.add(userData);
            } else {
              Map<String, dynamic> minimalStudent = {
                'id': studentId,
                'userFirst': studentRef is Map ? (studentRef['name']?.toString().split(' ').first ?? 'Student') : 'Student',
                'userLast': studentRef is Map ? 
                  ((studentRef['name']?.toString().split(' ').length ?? 0) > 1 ? studentRef['name'].toString().split(' ').last : '#$studentId') : 
                  '#${studentId ?? "unknown"}',
                'imageSeed': studentId,
              };
              loadedStudents.add(minimalStudent);
            }
          } catch (e) {
            print('Error processing student: $e');
          }
        }

        Map<String, dynamic> groupsData = data['groups'] ?? {};
        Map<String, Map<String, dynamic>> loadedGroups = Map<String, Map<String, dynamic>>.from(
          groupsData.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)))
        );

        setState(() {
          // Store assignments for later use
          assignments = loadedAssignments;
          students = loadedStudents;
          filteredStudents = List.from(loadedStudents);
          groups = loadedGroups;
          isLoading = false;
        });

        if (students.isNotEmpty) {
          _loadStudentPerformanceData();
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading section data: $e'))
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Helper method to get assignment details
  Map<String, dynamic>? _getAssignmentDetails(String assignmentId) {
    return assignments.firstWhere(
      (assignment) => assignment['assignmentId'] == assignmentId,
      orElse: () => {},
    );
  }

  // Helper method to check if submission is late
  bool _isSubmissionLate(Timestamp submissionTime, Timestamp? dueDate) {
    if (dueDate == null) return false;
    return submissionTime.compareTo(dueDate) > 0;
  }

  Future<void> _loadStudentPerformanceData() async {
    setState(() {
      isLoadingPerformance = true;
    });

    try {
      QuerySnapshot quizHistorySnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .doc(args.sectionId)
          .collection('quizHistory')
          .get();

      Map<String, Map<String, dynamic>> performanceData = {};

      for (var doc in quizHistorySnapshot.docs) {
        Map<String, dynamic> result = doc.data() as Map<String, dynamic>;
        String studentId = result['userId'] ?? '';

        if (studentId.isEmpty) continue;

        if (!performanceData.containsKey(studentId)) {
          performanceData[studentId] = {
            'totalQuizzes': 0,
            'totalCorrect': 0,
            'totalQuestions': 0,
            'quizzes': [],
            'scoreByDate': <Map<String, dynamic>>[],
          };
        }

        List<dynamic> questionResults = result['results'] ?? [];
        int correctCount = questionResults.where((r) => r == true).length;
        int totalQuestions = questionResults.length;

        performanceData[studentId]!['totalQuizzes'] = (performanceData[studentId]!['totalQuizzes'] as int) + 1;
        performanceData[studentId]!['totalCorrect'] = (performanceData[studentId]!['totalCorrect'] as int) + correctCount;
        performanceData[studentId]!['totalQuestions'] = (performanceData[studentId]!['totalQuestions'] as int) + totalQuestions;

        (performanceData[studentId]!['quizzes'] as List).add({
          'assignmentId': result['assignmentId'],
          'timestamp': result['timestamp'],
          'correctCount': correctCount,
          'totalQuestions': totalQuestions,
          'score': totalQuestions > 0 ? correctCount / totalQuestions * 100 : 0,
          'stars': result['stars'] ?? 0,
        });

        if (result['timestamp'] != null) {
          DateTime quizDate = (result['timestamp'] as Timestamp).toDate();
          double score = totalQuestions > 0 ? correctCount / totalQuestions : 0;
          (performanceData[studentId]!['scoreByDate'] as List).add(
            {'date': quizDate, 'score': score}
          );
        }
      }

      for (var studentId in performanceData.keys) {
        (performanceData[studentId]!['quizzes'] as List).sort((a, b) {
          Timestamp aTime = a['timestamp'] as Timestamp;
          Timestamp bTime = b['timestamp'] as Timestamp;
          return bTime.compareTo(aTime);
        });
      }

      if (mounted) {
        setState(() {
          studentPerformance = performanceData;
          isLoadingPerformance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingPerformance = false;
        });
      }
    }
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }

  Future<void> _createNewGroup() async {
    TextEditingController nameController = TextEditingController();
    // String? groupName;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create New Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownMenu(
                controller: nameController,
                leadingIcon: Icon(
                        Constants.groupNameIconStringMap[nameController.text] ?? Icons.exit_to_app,
                      ),
                dropdownMenuEntries: Constants.groupNameIconStringMap.keys
                          .map<DropdownMenuEntry>((iconName) {
                        return DropdownMenuEntry<String>(
                            label: iconName,
                            value: iconName,
                            leadingIcon:
                                Icon(Constants.groupNameIconStringMap[iconName]));
                      }).toList(),
                      onSelected: (value) {
                        nameController.text = value;
                      }
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a group name'))
                  );
                  return;
                }

                Navigator.of(context).pop();

                try {
                  await FirebaseFirestore.instance
                      .collection('classes')
                      .doc(args.sectionId)
                      .update({
                    'groups.$name': {
                      'score': 0,
                      'members': [],
                    }
                  });

                  _loadSectionData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating group: $e'))
                  );
                }
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _assignStudentToGroup(Map<String, dynamic> student) async {
    String studentId = student['id'];
    String currentGroup = findStudentGroup(studentId);
    String? selectedGroup;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Assign to Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${student['userFirst']} ${student['userLast']}'),
              SizedBox(height: 8),
              Text('Current Group: $currentGroup'),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Select Group'),
                value: selectedGroup,
                items: [
                  DropdownMenuItem(value: 'None', child: Text('None (Remove from group)')),
                  ...groups.keys.map((name) => DropdownMenuItem(value: name, child: Text(name))),
                ],
                onChanged: (value) {
                  selectedGroup = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedGroup == null) {
                  Navigator.of(context).pop();
                  return;
                }

                Navigator.of(context).pop();

                try {
                  print('a');
                  if (currentGroup != 'None') {
                            print('b');
                    List<dynamic> members = groups[currentGroup]?['members'] ?? [];
                    Map<String, dynamic>? memberToRemove;

                    for (var member in members) {
                      if (member['uId'] == studentId) {
                        memberToRemove = Map<String, dynamic>.from(member);
                        break;
                      }
                    }
                    print(memberToRemove);

                    if (memberToRemove != null) {
                      await FirebaseFirestore.instance
                          .collection('classes')
                          .doc(args.sectionId)
                          .update({
                        'groups.$currentGroup.members': FieldValue.arrayRemove([memberToRemove])
                      });

                      await Future.delayed(Duration(milliseconds: 300));
                    }
                  }

                  if (selectedGroup != 'None') {
                    await FirebaseFirestore.instance
                        .collection('classes')
                        .doc(args.sectionId)
                        .update({
                      'groups.$selectedGroup.members': FieldValue.arrayUnion([
                        {
                          'uId': studentId, 
                          'name': '${student['userFirst']} ${student['userLast']}',
                          'icon': student['userImageSeed'] ?? ''
                        }
                      ])
                    });
                  }

                  _loadSectionData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error assigning student: $e'))
                  );
                }
              },
              child: Text('Assign'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editGroup(String groupName, Map<String, dynamic> groupData) async {
    TextEditingController nameController = TextEditingController(text: groupName);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Group Name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a group name'))
                  );
                  return;
                }

                Navigator.of(context).pop();

                try {
                  if (newName == groupName) {
                    return;
                  } else {
                    final db = FirebaseFirestore.instance;
                    await db.runTransaction((transaction) async {
                      DocumentSnapshot sectionDoc = await transaction.get(
                          db.collection('classes').doc(args.sectionId));

                      if (!sectionDoc.exists) return;

                      Map<String, dynamic> data = sectionDoc.data() as Map<String, dynamic>;
                      Map<String, dynamic> groupsData = data['groups'] ?? {};

                      if (!groupsData.containsKey(groupName)) return;

                      if (groupsData.containsKey(newName) && newName != groupName) {
                        throw Exception('A group with this name already exists');
                      }

                      Map<String, dynamic> currentGroupData = groupsData[groupName] as Map<String, dynamic>;

                      if (newName != groupName) {
                        transaction.update(
                          db.collection('classes').doc(args.sectionId),
                          {
                            'groups.$newName': currentGroupData,
                            'groups.$groupName': FieldValue.delete()
                          }
                        );
                      }
                    });

                    _loadSectionData();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating group: $e'))
                  );
                }
              },
              child: Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteGroup(String groupName) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Group'),
        content: Text(
          'Are you sure you want to delete the group "$groupName"? ' +
          'All students will be removed from this group.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance
        .collection('classes')
        .doc(args.sectionId)
        .update({
          'groups.$groupName': FieldValue.delete()
        });

      _loadSectionData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group deleted successfully'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting group: $e'))
      );
    }
  }

  void _showStudentDetails(Map<String, dynamic> student) {
    final String studentId = student['id'];
    final Map<String, dynamic>? performance = studentPerformance[studentId];
    
    final int totalQuizzes = performance?['totalQuizzes'] ?? 0;
    final int totalCorrect = performance?['totalCorrect'] ?? 0;
    final int totalQuestions = performance?['totalQuestions'] ?? 0;
    final double averageScore = totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0;
    final List<dynamic> quizzes = performance?['quizzes'] ?? [];
    final List<dynamic> scoreByDate = performance?['scoreByDate'] ?? [];
    
    // Process chart data
    List<ScorePoint> chartData = [];
    if (scoreByDate.isNotEmpty) {
      for (var data in scoreByDate) {
        final date = data['date'] as DateTime;
        final score = data['score'] as double;
        chartData.add(ScorePoint(date, score * 100));
      }
      // Sort the chart data by date
      chartData.sort((a, b) => a.date.compareTo(b.date));
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(
                      Constants.profilePictureRoute + (student['imageSeed'] ?? '')),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${student['userFirst']} ${student['userLast']}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text('Group: ${findStudentGroup(student['id'])}'),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              Text(
                'Performance Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 10),
              
              if (isLoadingPerformance)
                CircularProgressIndicator()
              else if (totalQuizzes == 0)
                Text('No quiz data available for this student')
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildMetricCard(
                              context, 
                              'Overall Score', 
                              '${averageScore.toStringAsFixed(1)}%',
                              _getScoreColor(averageScore / 100),
                            ),
                            _buildMetricCard(
                              context, 
                              'Quizzes Taken', 
                              '$totalQuizzes',
                              Theme.of(context).colorScheme.primary,
                            ),
                            _buildMetricCard(
                              context, 
                              'Questions', 
                              '$totalCorrect/$totalQuestions',
                              Theme.of(context).colorScheme.secondary,
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        
                        // Custom progress chart
                        if (chartData.isNotEmpty) ...[
                          Text('Progress Over Time', 
                              style: Theme.of(context).textTheme.titleMedium),
                          SizedBox(height: 10),
                          Container(
                            height: 200,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SimpleLineChart(dataPoints: chartData),
                          ),
                          SizedBox(height: 20),
                        ],
                        
                        Text('Recent Quiz Results', 
                            style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(height: 10),
                        ...quizzes.take(5).map((quiz) {
                          DateTime quizDate = (quiz['timestamp'] as Timestamp).toDate();
                          String dateStr = '${quizDate.month}/${quizDate.day}/${quizDate.year}';
                          double score = quiz['score'] as double;
                          String assignmentId = quiz['assignmentId'] ?? '';
                          
                          // Get assignment details to check if submission is late
                          Map<String, dynamic>? assignment = _getAssignmentDetails(assignmentId);
                          String quizName = assignment?['assignmentName'] ?? 'Unnamed Quiz';
                          
                          // Check if submission was late
                          bool isLate = false;
                          if (assignment != null && assignment.isNotEmpty && assignment['dueDate'] != null) {
                            isLate = _isSubmissionLate(
                              quiz['timestamp'] as Timestamp, 
                              assignment['dueDate'] as Timestamp
                            );
                          }
                          
                          return ListTile(
                            leading: Icon(Icons.quiz, 
                                color: _getScoreColor(score / 100)),
                            title: Text(quizName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Score: ${score.toStringAsFixed(1)}%'),
                                Text(
                                  'Submitted: $dateStr${isLate ? " (Late)" : ""}',
                                  style: TextStyle(
                                    color: isLate ? Colors.red : null,
                                    fontWeight: isLate ? FontWeight.bold : null,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          );
                        }).toList(),
                        
                        if (quizzes.length > 5)
                          Text('+ ${quizzes.length - 5} more quizzes', 
                              style: TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
              
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.group),
                    label: Text('Assign to Group'),
                    onPressed: () {
                      Navigator.pop(context);
                      _assignStudentToGroup(student);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.2,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.9) return Colors.green;
    if (score >= 0.8) return Colors.green[700]!;
    if (score >= 0.7) return Colors.lime;
    if (score >= 0.6) return Colors.amber;
    if (score >= 0.5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${args.className}: ${args.sectionName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Students'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStudentsTab(),
                _buildGroupsTab(),
              ],
            ),
    );
  }

  Widget _buildStudentsTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('All Students (${students.length})', 
                  style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                icon: Icon(Icons.person_add),
                label: Text('Invite Student'),
                onPressed: () {
                  _showInviteOptions();
                },
              ),
            ],
          ),
        ),
        
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search students...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        
        SizedBox(height: 16),
        
        Expanded(
          child: students.isEmpty ? 
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No students in this section'),
                  SizedBox(height: 8),
                  Text('Use "Invite Student" to add students to this section', 
                    style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadSectionData,
                    child: Text('Refresh'),
                  )
                ],
              )
            ) : 
            filteredStudents.isEmpty ?
              Center(child: Text('No matching students found')) :
              ListView.builder(
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) {
                  final student = filteredStudents[index];
                  return _buildStudentListItem(student);
                },
              ),
        ),
      ],
    );
  }

  Widget _buildStudentListItem(Map<String, dynamic> student) {
    String currentGroup = findStudentGroup(student['id']);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(
              Constants.profilePictureRoute + (student['imageSeed'] ?? '')),
        ),
        title: Text('${student['userFirst']} ${student['userLast']}'),
        subtitle: Text('Group: $currentGroup'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.group),
              tooltip: 'Assign to group',
              onPressed: () => _assignStudentToGroup(student),
            ),
          ],
        ),
        onTap: () {
          _showStudentDetails(student);
        },
      ),
    );
  }

  Widget _buildGroupsTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Groups (${groups.length})', 
                  style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Create Group'),
                onPressed: _createNewGroup,
              ),
            ],
          ),
        ),
        
        Expanded(
          child: groups.isEmpty ?
            Center(child: Text('No groups created yet')) :
            ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final groupName = groups.keys.elementAt(index);
                final groupData = groups[groupName]!;
                return _buildGroupCard(groupName, groupData);
              },
            ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(String groupName, Map<String, dynamic> groupData) {
    List<dynamic> members = groupData['members'] ?? [];
    final int score = groupData['score'] ?? 0;
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.group, size: 36, color: Theme.of(context).primaryColor),
            title: Text(groupName, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${members.length} members • $score stars'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  tooltip: 'Edit group',
                  onPressed: () => _editGroup(groupName, groupData),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  tooltip: 'Delete group',
                  onPressed: () => _deleteGroup(groupName),
                ),
              ],
            ),
          ),
          
          Divider(),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          
          members.isEmpty
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('No members in this group', style: TextStyle(fontStyle: FontStyle.italic)),
              )
            : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final String memberIcon = member['icon'] ?? '';
                
                return ListTile(
                  title: Text(member['name'] ?? 'Unknown'),
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                      Constants.profilePictureRoute + memberIcon
                    ),
                    child: memberIcon.isEmpty ? Icon(Icons.person) : null,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showInviteOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invite Students'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share the class join code with your students:'),
            SizedBox(height: 16),
            
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                .collection('invites')
                .where('classId', isEqualTo: args.sectionId)
                .limit(1)
                .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                String joinCode = snapshot.data?.docs.isNotEmpty == true 
                  ? snapshot.data!.docs.first.id 
                  : 'No join code found';
                
                return Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          joinCode,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: joinCode));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Join code copied to clipboard'))
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

class ScorePoint {
  final DateTime date;
  final double score;
  
  ScorePoint(this.date, this.score);
}

class SimpleLineChart extends StatelessWidget {
  final List<ScorePoint> dataPoints;
  
  const SimpleLineChart({Key? key, required this.dataPoints}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) return Center(child: Text("No data available"));
    
    final firstDate = dataPoints.first.date;
    final lastDate = dataPoints.last.date;
    final totalDays = lastDate.difference(firstDate).inDays + 1;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final chartHeight = height - 40;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomPaint(
                size: Size(width, chartHeight),
                painter: ChartPainter(
                  dataPoints: dataPoints,
                  minDate: firstDate,
                  maxDate: lastDate,
                ),
              ),
            ),
            SizedBox(
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('M/d').format(firstDate), 
                      style: TextStyle(fontSize: 10)),
                  Text(DateFormat('M/d').format(lastDate), 
                      style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<ScorePoint> dataPoints;
  final DateTime minDate;
  final DateTime maxDate;
  
  ChartPainter({required this.dataPoints, required this.minDate, required this.maxDate});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    final dotPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;
      
    final linePaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
      
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (size.height * i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    
    List<Offset> points = [];
    for (var point in dataPoints) {
      final dayDiff = point.date.difference(minDate).inDays;
      final totalDays = maxDate.difference(minDate).inDays + 1;
      final x = (dayDiff / totalDays) * size.width;
      final y = size.height - ((point.score / 100) * size.height);
      points.add(Offset(x, y));
    }
    
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
    
    for (var point in points) {
      canvas.drawCircle(point, 5, dotPaint);
    }
    
    final textStyle = TextStyle(color: Colors.black, fontSize: 10);
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );
    
    for (int i = 0; i <= 4; i++) {
      final value = (i * 25).toString();
      textPainter.text = TextSpan(text: value, style: textStyle);
      textPainter.layout();
      final y = size.height - (size.height * i / 4) - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(-20, y));
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
