import 'package:flutter/material.dart';

class ErrorWidget extends StatelessWidget{
    const ErrorWidget({ super.key, required this.errorMessage });

    final String errorMessage;

    @override
    Widget build(BuildContext context) {
        return Center(
            child: Column()
        );
    }
}