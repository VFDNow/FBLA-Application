import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
          QuerySnapshot studentsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('classes', arrayContains: {'classId': sectionId})
              .get();
              
          sectionData['studentCount'] = studentsSnapshot.docs.length;
          
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
      
      List<Map<String, dynamic>> loadedAssignments = [];
      
      // Map to track which sections each assignment is assigned to
      Map<String, List<String>> assignmentSections = {};
      
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
          
          // Track which sections this assignment appears in
          if (!assignmentSections.containsKey(assignmentId)) {
            assignmentSections[assignmentId] = [];
            
            // Add the assignment data only once (the first time we see it)
            loadedAssignments.add({
              ...assignment as Map<String, dynamic>,
              'sections': <String>[], // Will be filled below
            });
          }
          
          // Add this section to the assignment's sections list
          assignmentSections[assignmentId]!.add(sectionHour);
        }
      }
      
      // Add section information to assignments
      for (var assignment in loadedAssignments) {
        String assignmentId = assignment['assignmentId'];
        assignment['sections'] = assignmentSections[assignmentId] ?? [];
      }
      
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
    // We'll implement this later with a dialog
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create Assignment'),
          content: Text('Assignment creation feature coming soon!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            )
          ],
        );
      }
    );
  }

  // Method to preview quiz
  Future<void> _previewQuiz(Map<String, dynamic> assignment) async {
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
      
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
      });
      
      // Capture the context before async operation
      final currentContext = context;
      
      // Show the quiz preview dialog
      if (mounted) {
        showDialog(
          context: currentContext,
          builder: (dialogContext) => QuizPreviewDialog(quiz: quiz),
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
    
    // Get current assignment sections
    List<String> currentSections = List<String>.from(assignment['sections'] ?? []);
    
    // Get section IDs and hours
    Map<String, String> sectionHoursMap = {};
    for (var section in sections) {
      sectionHoursMap[section['classId']] = section['classHour'] ?? 'Unknown';
    }
    
    // Capture context before async operation
    final currentContext = context;
    
    // Find sections where this assignment is currently assigned
    Set<String> assignedSectionIds = {};
    for (String sectionId in args.sectionIds) {
      DocumentSnapshot sectionDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(sectionId)
          .get();
      
      if (!sectionDoc.exists) continue;
      
      Map<String, dynamic> sectionData = sectionDoc.data() as Map<String, dynamic>;
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
              // Add assignment to each selected section
              for (String sectionId in selectedSectionIds) {
                await FirebaseFirestore.instance
                    .collection('classes')
                    .doc(sectionId)
                    .update({
                      'assignments': FieldValue.arrayUnion([assignment])
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
                final List<String> assignedSections = 
                    List<String>.from(assignment['sections'] ?? []);
                
                return Card(
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
                        onTap: () => _previewQuiz(assignment),
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
                                for (var section in assignedSections)
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
                );
              },
            ),
        ],
      ),
    );
  }
}

// Add a new QuizPreviewDialog widget
class QuizPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> quiz;
  
  const QuizPreviewDialog({Key? key, required this.quiz}) : super(key: key);

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
                  return _buildQuestionCard(context, question, index);
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

  Widget _buildQuestionCard(BuildContext context, Map<String, dynamic> question, int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${index + 1}: ${question['questionTitle'] ?? 'Question'}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
