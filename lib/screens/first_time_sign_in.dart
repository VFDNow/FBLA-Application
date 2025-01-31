import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:fbla_application/utils/global_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirstTimeSignIn extends StatefulWidget {
  const FirstTimeSignIn({super.key});

  @override
  State createState() => _FirstTimeSignInState();
}

enum EducatorType { student, teacher }

class _FirstTimeSignInState extends State<FirstTimeSignIn> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  final PageController pageController = PageController();

  final _nameFormKey = GlobalKey<FormState>();

  var currentPfpKey = "";
  var rnjesus = Random();

  void setCurrentPfpKey(String key) {
    setState(() {
      currentPfpKey = key;
    });
  }

  EducatorType selectedType = EducatorType.student;

  @override
  void dispose() {
    pageController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: PageView(controller: pageController, children: [
        buildNameScreen(context),
        buildProfilePicScreen(context),
        buildUserTypeSelectionScreen(context),
      ]),
    );
  }

  Center buildProfilePicScreen(context) {
    return Center(
        child: Column(children: [
      CircleAvatar(
        radius: 100,
        backgroundImage: Image.network(
                Constants.profilePictureRoute + currentPfpKey.toString())
            .image,
      ),
      const SizedBox(height: 20),
      ElevatedButton(
          onPressed: () {
            setCurrentPfpKey(rnjesus.nextInt(999999999).toString());
          },
          child: const Text('Randomize')),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              pageController.animateToPage(0,
                  duration: Duration(milliseconds: 750),
                  curve: Curves.easeInOutCubic);
            },
            child: const Text('Back'),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: () {
              pageController.animateToPage(2,
                  duration: Duration(milliseconds: 750),
                  curve: Curves.easeInOutCubic);
            },
            child: const Text('That\'s Me!'),
          ),
        ],
      )
    ]));
  }

  Center buildUserTypeSelectionScreen(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text('I am a:', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 20),
          SegmentedButton<EducatorType>(
            segments: const <ButtonSegment<EducatorType>>[
              ButtonSegment<EducatorType>(
                value: EducatorType.student,
                label: Text('Student'),
                icon: Icon(Icons.school),
              ),
              ButtonSegment<EducatorType>(
                  value: EducatorType.teacher,
                  label: Text('Teacher'),
                  icon: Icon(Icons.person)),
            ],
            selected: <EducatorType>{selectedType},
            onSelectionChanged: (Set<EducatorType> newSelection) {
              setState(() {
                selectedType = newSelection.first;
              });
            },
            multiSelectionEnabled: false,
            showSelectedIcon: false,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  pageController.animateToPage(1,
                      duration: Duration(milliseconds: 750),
                      curve: Curves.easeInOutCubic);
                },
                child: const Text('Back'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () {
                  final db = FirebaseFirestore.instance;
                  db
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .set({
                    'User First': firstNameController.text,
                    'User Last': lastNameController.text,
                    'User Type': selectedType == EducatorType.student
                        ? 'Student'
                        : 'Teacher',
                    'User Image Seed': currentPfpKey,
                  }).then((value) {
                    Navigator.pushReplacementNamed(
                        context, Constants.homeRoute);
                  }).onError((error, stackTrace) {
                    GlobalWidgets(context).showSnackBar(
                        content: "Error Creating User!",
                        backgroundColor: Colors.red);
                  });
                },
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SingleChildScrollView buildNameScreen(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text('Welcome!', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 20),
          Text('Please Enter Your Name',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Form(
              key: _nameFormKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name.';
                        } else if (value.contains(RegExp('[^a-zA-Z]'))) {
                          return 'Please enter a valid name.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name.';
                        } else if (value.contains(RegExp('[^a-zA-Z]'))) {
                          return 'Please enter a valid name.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_nameFormKey.currentState!.validate()) {
                pageController.animateToPage(1,
                    duration: Duration(milliseconds: 750),
                    curve: Curves.easeInOutCubic);
              } else {
                GlobalWidgets(context).showSnackBar(
                    content: "Please Enter Your Name",
                    backgroundColor: Colors.red);
              }
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
