import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  String _className = '';
  String _classDescription = '';
  String _sectionName = ''; // Add field for section name
  String currentIcon = "General";
  
  // Controllers for form fields to easily reset them
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _sectionNameController = TextEditingController(); // Add controller

  @override
  void initState() {
    super.initState();
    // Set default section name
    _sectionNameController.text = 'Period 1';
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _descriptionController.dispose();
    _sectionNameController.dispose(); // Dispose section controller
    super.dispose();
  }

  // Method to reset form fields
  void _resetForm() {
    _formKey.currentState!.reset();
    _classNameController.clear();
    _descriptionController.clear();
    _sectionNameController.text = 'Period 1'; // Reset section name
    setState(() {
      currentIcon = "General";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Class'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                        padding: const EdgeInsets.all(16),
                        child: Icon(Constants.subjectIconStringMap[currentIcon],
                            size: 50)),
                    SizedBox(width: 25),
                    Expanded(
                      child: TextFormField(
                        controller: _classNameController,
                        decoration: InputDecoration(labelText: 'Class Name'),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a class name';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          _className = value!;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Add section name field
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _sectionNameController,
                  decoration: InputDecoration(
                    labelText: 'First Section Name (e.g., Period 1, Block A)',
                    hintText: 'Enter a name for your first class section',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a section name';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _sectionName = value!;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  minLines: 1,
                  decoration: InputDecoration(labelText: 'Class Description'),
                  onSaved: (value) {
                    _classDescription = value!;
                  },
                ),
              ),
              SizedBox(height: 20),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Class Subject",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  DropdownMenu(
                      enableFilter: true,
                      initialSelection: currentIcon,
                      leadingIcon: Icon(
                        Constants.subjectIconStringMap[currentIcon],
                      ),
                      dropdownMenuEntries: Constants.subjectIconStringMap.keys
                          .map<DropdownMenuEntry>((iconName) {
                        return DropdownMenuEntry<String>(
                            label: iconName,
                            value: iconName,
                            leadingIcon:
                                Icon(Constants.subjectIconStringMap[iconName]));
                      }).toList(),
                      onSelected: (value) {
                        setState(() {
                          currentIcon = value!;
                        });
                      }),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    
                    // Check if a class with same name already exists
                    String? userId = FirebaseAuth.instance.currentUser?.uid;
                    if (userId != null) {
                      QuerySnapshot existingClasses = await FirebaseFirestore.instance
                          .collection('classes')
                          .where('owner', isEqualTo: userId)
                          .where('className', isEqualTo: _className)
                          .get();
                      
                      if (existingClasses.docs.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('You already have a class with this name'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }

                    // Create a unique class ID for the base class
                    DocumentReference baseClassRef = FirebaseFirestore.instance.collection('classTemplates').doc();
                    String baseClassId = baseClassRef.id;
                    
                    // Create the base class template
                    await baseClassRef.set({
                      'className': _className,
                      'classDesc': _classDescription,
                      'classIcon': currentIcon,
                      'owner': userId,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    
                    // Now create the first section using the user-provided section name
                    await FirebaseFirestore.instance.collection('classes').add({
                      'className': _className,
                      'classDesc': _classDescription,
                      'classIcon': currentIcon,
                      'owner': userId,
                      'baseClassId': baseClassId,
                      'classHour': _sectionName, // Use the user-provided section name
                      'createdAt': FieldValue.serverTimestamp(),
                    }).then((value) {
                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Class created successfully!')),
                      );
                      
                      // Ask user what to do next
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Class Created'),
                            content: Text('Would you like to create another class or exit to manage your classes?'),
                            actions: [
                              TextButton(
                                child: Text('Create Another'),
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close dialog
                                  _resetForm();
                                },
                              ),
                              TextButton(
                                child: Text('Manage Classes'),
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close dialog
                                  // Navigate to teacher home page
                                  Navigator.of(context).pushReplacementNamed(Constants.teacherHomeRoute);
                                },
                              ),
                            ],
                          );
                        },
                      );
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create class: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    });
                  }
                },
                child: Text('Create Class'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
