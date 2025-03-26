import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _TeacherClassHomeScreenState extends State<TeacherClassHomeScreen> {
  List<Map<String, dynamic>> sections = [];
  bool isLoading = true;
  late TeacherClassHomeArgs args;
  String? baseClassId;
  Map<String, dynamic>? baseClassData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    args = ModalRoute.of(context)!.settings.arguments as TeacherClassHomeArgs;
    baseClassId = args.baseClassId;
    _loadSections();
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

  // Add a new section to this class
  Future<void> _addSection() async {
    TextEditingController sectionController = TextEditingController(text: 'Section ${sections.length + 1}');
    
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
                if (sectionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Section name cannot be empty'))
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

  @override
  void dispose() {
    // Clean up any resources, listeners, or subscriptions here
    super.dispose();
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
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (mounted) {
                  await _loadSections();
                }
                return;
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class header
                    Card(
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
                    ),
                    
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
                                      color: Theme.of(context).colorScheme.surfaceVariant,
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
              ),
            ),
    );
  }
}
