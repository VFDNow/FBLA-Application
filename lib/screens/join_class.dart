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
                SizedBox(
                  height: 12,
                ),
                SizedBox(
                  width: 500,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                        decoration: InputDecoration(labelText: 'Class Code'),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a code';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          _joinCode = value!;
                        }),
                  ),
                ),
                SizedBox(
                  height: 12,
                ),
                ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        var db = FirebaseFirestore.instance;
                        db
                            .collection("invites")
                            .doc(_joinCode)
                            .get()
                            .then((value) {
                          if (context.mounted) {
                            if (value.exists) {
                              var data = value.data();
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return JoinClassDialog(data: data);
                                  });
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
    required this.data,
  });

  final Map<String, dynamic>? data;

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
                  Constants
                      .subjectIconStringMap[data?["classIcon"] ?? "General"],
                  size: 65,
                ),
              ),
              Text(
                data?["className"] ?? "Class Name",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                data?["teacherName"] ?? "Teacher Name",
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                data?["classHour"] ?? "Hour",
                style: Theme.of(context).textTheme.labelMedium,
              ),
              SizedBox(
                width: 225,
                child: Text(
                  textAlign: TextAlign.center,
                  data?["classDesc"] ?? "Description",
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
                        <String, dynamic>{"classId": data?["classId"]},
                      );
                      if (result.data["res"]) {
                        if (context.mounted) {
                          GlobalWidgets(context).showSnackBar(
                            content: result.data["result"],
                          );
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                              context, Constants.classHomeRoute,
                              arguments: ClassHomeArgs(data?["classId"]));
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
                    } on FirebaseFunctionsException catch (error) {
                      if (context.mounted) {
                        GlobalWidgets(context).showSnackBar(
                            content: "Error joining class.  Please Try Again.",
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
