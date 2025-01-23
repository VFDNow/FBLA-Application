import 'package:flutter/material.dart';
import 'package:fbla_application/utils/constants.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 20),
              const Text('Home', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 20),
            ],
          ),
        ),
          
      ),
      floatingActionButton: 
      TextButton(
        onPressed: () {
          Navigator.pushReplacementNamed(context, Constants.profileRoute);
        },
        child: Text('To Profile')
      ),
    );
  }
}
