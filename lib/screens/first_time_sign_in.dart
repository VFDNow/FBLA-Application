

import 'package:flutter/material.dart';

class FirstTimeSignIn extends StatelessWidget{
  const FirstTimeSignIn({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('First Time Sign In')),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 20),
              const Text('First Time Sign In', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}