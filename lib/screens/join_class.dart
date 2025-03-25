import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/utils/global_widgets.dart';
import 'package:flutter/material.dart';

class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key});

  @override
  _JoinClassScreenState createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final _formKey = GlobalKey<FormState>();
  String _joinCode = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Class'),
      ),
      body: Center(
        child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Join a Class",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: 500,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                        decoration: InputDecoration(labelText: 'Class Code'),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a code';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          // Save the value in all uppercase to ensure consistent behavior
                          _joinCode = value!.trim().toUpperCase();                        
                      }),
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        var db = FirebaseFirestore.instance;
                        db
                            .collection("invites")
                            .doc(_joinCode)
                            .get()
                            .then((inviteDoc) async {
                          if (context.mounted) {
                            if (inviteDoc.exists) {
                              var inviteData = inviteDoc.data();
                              String classId = inviteData?['classId'];
                              
                              // Fetch the class data
                              DocumentSnapshot classDoc = await db
                                  .collection('classes')
                                  .doc(classId)
                                  .get();
                              
                              if (!classDoc.exists) {
                                GlobalWidgets(context).showSnackBar(
                                  content: 'Class not found',
                                  backgroundColor: Theme.of(context).colorScheme.error
                                );
                                return;
                              }
                              
                              Map<String, dynamic> classData = classDoc.data() as Map<String, dynamic>;
                              
                              // Fetch teacher info
                              DocumentSnapshot teacherDoc = await db
                                  .collection('users')
                                  .doc(classData['owner'])
                                  .get();
                              
                              Map<String, dynamic> teacherData = teacherDoc.data() as Map<String, dynamic>;
                              String teacherName = "${teacherData['userFirst']} ${teacherData['userLast']}";
                              
                              // Display confirmation dialog
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return JoinClassDialog(
                                      classId: classId,
                                      className: classData['className'] ?? 'Class',
                                      classHour: classData['classHour'] ?? 'N/A',
                                      classIcon: classData['classIcon'] ?? 'General',
                                      classDesc: classData['classDesc'] ?? '',
                                      teacherName: teacherName,
                                    );
                                  }
                                );
                              }
                            } else {
                              GlobalWidgets(context).showSnackBar(
                                  content:
                                      'Couldn\'t find class with code: "$_joinCode"',
                                  backgroundColor:
                                      Theme.of(context).colorScheme.error);
                            }
                          }
                        }).onError((error, stackTrace) {
                          if (context.mounted) {
                            GlobalWidgets(context).showSnackBar(
                                content: 'Error Finding Class: "$_joinCode"',
                                backgroundColor:
                                    Theme.of(context).colorScheme.error);
                          }
                        });
                      }
                    },
                    child: Text("Join Class"))
              ],
            )),
      ),
    );
  }
}

class JoinClassDialog extends StatelessWidget {
  const JoinClassDialog({
    super.key,
    required this.classId,
    required this.className,
    required this.classHour,
    required this.classIcon,
    required this.classDesc,
    required this.teacherName,
  });

  final String classId;
  final String className;
  final String classHour;
  final String classIcon;
  final String classDesc;
  final String teacherName;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text("Are you Sure?"),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Constants.subjectIconStringMap[classIcon] ?? Icons.book,
                  size: 65,
                ),
              ),
              Text(
                className,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                teacherName,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                classHour,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              SizedBox(
                width: 225,
                child: Text(
                  textAlign: TextAlign.center,
                  classDesc,
                  style: Theme.of(context).textTheme.bodyMedium,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("No")),
              TextButton(
                  onPressed: () async {
                    try {
                      final result = await FirebaseFunctions.instance
                          .httpsCallable("onClassJoin")
                          .call(
                        <String, dynamic>{"classId": classId},
                      );
                      if (result.data["res"]) {
                        if (context.mounted) {
                          GlobalWidgets(context).showSnackBar(
                            content: result.data["result"],
                          );
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                              context, Constants.classHomeRoute,
                              arguments: ClassHomeArgs(classId));
                        }
                      } else {
                        if (context.mounted) {
                          GlobalWidgets(context).showSnackBar(
                              content: result.data["result"],
                              backgroundColor:
                                  Theme.of(context).colorScheme.error);
                          Navigator.pop(context);
                        }
                      }
                    } on FirebaseFunctionsException {
                      if (context.mounted) {
                        GlobalWidgets(context).showSnackBar(
                            content: "Error joining class. Please Try Again.",
                            backgroundColor:
                                Theme.of(context).colorScheme.error);
                      }
                    }
                  },
                  child: Text("Join")),
            ],
          ),
        ),
      ],
    );
  }
}
