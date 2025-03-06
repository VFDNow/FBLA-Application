import 'dart:math';

import 'package:fbla_application/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class QuizAnswer extends StatefulWidget {
  final String body;
  final String? iconName;
  final Color? color;
  final TextStyle? textStyle;
  final Function onTap;

  const QuizAnswer({
    Key? key,
    required this.body,
    required this.onTap,
    this.iconName,
    this.color,
    this.textStyle,
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
        color: widget.color ?? Theme.of(context).colorScheme.secondary,
        child: InkWell(
          splashColor: widget.color?.withValues(alpha: 0.8),
          highlightColor: widget.color?.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap as void Function()? ?? () {},
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: (widget.iconName != null &&
                              Constants.questionIconStringMap
                                  .containsKey(widget.iconName))
                          ? Icon(
                              widget.iconName != null
                                  ? Constants
                                      .questionIconStringMap[widget.iconName]
                                  : null,
                              size: clampDouble(
                                  min(constraints.maxHeight,
                                      constraints.maxWidth / 4),
                                  5,
                                  200),
                              color: (widget.color?.computeLuminance() ??
                                          Theme.of(context)
                                              .colorScheme
                                              .onSecondary
                                              .computeLuminance()) >
                                      0.5
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : Container(),
                    );
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.body,
                      style: widget.textStyle ??
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: (widget.color?.computeLuminance() ??
                                            Theme.of(context)
                                                .colorScheme
                                                .onSecondary
                                                .computeLuminance()) >
                                        0.5
                                    ? Colors.black
                                    : Colors.white,
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
