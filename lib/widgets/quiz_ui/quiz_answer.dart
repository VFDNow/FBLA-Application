import 'package:fbla_application/utils/constants.dart';
import 'package:flutter/material.dart';

class QuizAnswer extends StatefulWidget {
  final String body;
  final String? iconName;

  const QuizAnswer({
    Key? key,
    required this.body,
    this.iconName,
  }) : super(key: key);

  @override
  _QuizAnswerState createState() => _QuizAnswerState();
}

class _QuizAnswerState extends State<QuizAnswer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Card(
        elevation: 4,
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                      widget.iconName != null
                          ? Constants.questionIconStringMap[widget.iconName]
                          : null,
                      size: 50,
                      color:
                          Theme.of(context).colorScheme.onSecondaryContainer),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.body,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
