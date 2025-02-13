import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClassHomeArgs {
  final String classId;

  ClassHomeArgs(this.classId);
}

class ClassHome extends StatefulWidget {
  const ClassHome({super.key});

  @override
  _ClassHomeState createState() => _ClassHomeState();
}

class _ClassHomeState extends State<ClassHome> {
  Map<String, dynamic>? classData;

  @override
  Widget build(BuildContext context) {
    final ClassHomeArgs args;
    try {
      args = ModalRoute.of(context)!.settings.arguments as ClassHomeArgs;
    } catch (error) {
      return Scaffold(
        body: Center(child: Text("Error loading class.")),
      );
    }

    if (classData == null) {
      FirebaseFirestore.instance
          .collection("classes")
          .doc(args.classId)
          .get()
          .then((value) => {
                setState(() {
                  classData = value.data();
                })
              });

      return Scaffold(
        appBar: AppBar(
          title: const Text('Class Home'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text((classData?["className"] ?? "Error") + " Home"),
      ),
      body: Center(
        child: Text(classData?["className"] ?? "Error"),
      ),
    );
  }
}
