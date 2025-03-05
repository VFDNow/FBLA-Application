import 'package:fbla_application/utils/constants.dart';
import 'package:flutter/material.dart';

class ErrorWidget extends StatelessWidget {
  const ErrorWidget({super.key, required this.errorMessage});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Column(
              spacing: 15,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Icon(Icons.error,
                size: 50, color: Theme.of(context).colorScheme.error),
            Text(
              errorMessage,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, Constants.homeRoute);
                },
                child: Text("Return to Home"))
          ])),
    );
  }
}
