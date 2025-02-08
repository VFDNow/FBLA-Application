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
  String _classHour = '';
  String _classDescription = '';
  String currentIcon = "General";

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
                        child: Icon(Constants.iconStringMap[currentIcon],
                            size: 50)),
                    SizedBox(width: 25),
                    Expanded(
                      child: TextFormField(
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
                    SizedBox(width: 25),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(labelText: 'Class Hour'),
                        onSaved: (value) {
                          _classHour = value!;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
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
                        Constants.iconStringMap[currentIcon],
                      ),
                      dropdownMenuEntries: Constants.iconStringMap.keys
                          .map<DropdownMenuEntry>((iconName) {
                        return DropdownMenuEntry<String>(
                            label: iconName,
                            value: iconName,
                            leadingIcon:
                                Icon(Constants.iconStringMap[iconName]));
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
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    FirebaseFirestore.instance
                        .collection('classes')
                        .add({
                          'Class Name': _className,
                          'Class Hour': _classHour,
                          'Class Desc': _classDescription,
                          'Class Icon': currentIcon,
                          'Owner': FirebaseAuth.instance.currentUser?.uid,
                        })
                        .then((value) => print("Class Added"))
                        .catchError(
                            (error) => print("Failed to add class: $error"));
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
