import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/utils/global_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TeacherClassHomeArgs {
  String className;
  List<String> sectionIds;
  String classIcon;
  String? baseClassId; // Add this field to track the base class template

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
    
    // Fetch data for each section
    for (String sectionId in args.sectionIds) {
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

    setState(() {
      sections = loadedSections;
      isLoading = false;
    });
  }

  // Add a new section to this class
  Future<void> _addSection() async {
    TextEditingController sectionController = TextEditingController(text: 'Section ${sections.length + 1}');
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Section'),
          content: TextField(
            controller: sectionController,
            decoration: InputDecoration(labelText: 'Section Name/Hour'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (sectionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Section name cannot be empty'))
                  );
                  return;
                }
                
                Navigator.of(context).pop();
                
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
                    _loadSections();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('New section added successfully!'))
                    );
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
                      _loadSections();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('New section added successfully!'))
                      );
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding section: $e'),
                      backgroundColor: Colors.red,
                    )
                  );
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
      builder: (context) {
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
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    String newName = nameController.text.trim();
                    String newDesc = descController.text.trim();
                    
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Class name cannot be empty'))
                      );
                      return;
                    }
                    
                    Navigator.of(context).pop();
                    
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
                      _loadSections();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Class details updated successfully!'))
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating class: $e'),
                          backgroundColor: Colors.red,
                        )
                      );
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

  // Generate a unique join code for a section
  Future<void> _generateJoinCode(String classId, String className, String classHour, String classIcon) async {
    try {
      // Call a Firebase Function to generate a unique code and create the invite
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateJoinCode')
          .call({
            'classId': classId,
            'className': className,
            'classHour': classHour,
            'classIcon': classIcon,
            'teacherName': '${FirebaseAuth.instance.currentUser?.displayName ?? "Teacher"}'
          });
      
      if (result.data['success']) {
        _loadSections(); // Reload to show the new code
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Join code generated: ${result.data['code']}'))
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to generate code: ${result.data['error']}'),
              backgroundColor: Colors.red,
            )
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  // If no function exists, this is a fallback to generate directly in the app
  Future<void> _generateJoinCodeFallback(String classId, String className, String classHour, String classIcon) async {
    // Generate a 6-character alphanumeric code
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code;
    bool isUnique = false;
    
    // Keep generating until we find a unique code
    while (!isUnique) {
      code = '';
      for (int i = 0; i < 6; i++) {
        code += chars[DateTime.now().microsecondsSinceEpoch % chars.length];
      }
      
      // Check if code is unique
      DocumentSnapshot existingCode = await FirebaseFirestore.instance
          .collection('invites')
          .doc(code)
          .get();
          
      if (!existingCode.exists) {
        // Create the invite with the unique code
        await FirebaseFirestore.instance.collection('invites').doc(code).set({
          'classId': classId,
          'className': className,
          'classHour': classHour,
          'classIcon': classIcon,
          'teacherName': FirebaseAuth.instance.currentUser?.displayName ?? 'Teacher',
          'createdAt': FieldValue.serverTimestamp()
        });
        
        // Refresh the sections
        _loadSections();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Join code generated: $code'))
          );
        }
        
        isUnique = true;
      }
    }
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
          : SingleChildScrollView(
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
                          title: Text('Hour: ${section['classHour'] ?? 'N/A'}'),
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
                                  
                                  // Join Code section
                                  if (section['joinCode'] != null)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ListTile(
                                            title: Text('Join Code'),
                                            subtitle: Text(section['joinCode']),
                                            trailing: IconButton(
                                              icon: Icon(Icons.copy),
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: section['joinCode']));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Join code copied to clipboard'))
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    ElevatedButton.icon(
                                      icon: Icon(Icons.link),
                                      label: Text('Generate Join Code'),
                                      onPressed: () {
                                        _generateJoinCode(
                                          section['classId'],
                                          args.className,
                                          section['classHour'] ?? '',
                                          section['classIcon'] ?? args.classIcon
                                        );
                                      },
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
    );
  }
}
