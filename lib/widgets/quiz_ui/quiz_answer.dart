import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class QuizAnswer extends StatefulWidget {
  final String body;
  final String? iconName;
  final Color? color;
  final TextStyle? textStyle;
  final Function onTap;
  final bool isSelected;

  const QuizAnswer({
    super.key,
    required this.body,
    required this.onTap,
    this.iconName,
    this.color,
    this.textStyle,
    this.isSelected = false,
  });

  @override
  _QuizAnswerState createState() => _QuizAnswerState();
}

class _QuizAnswerState extends State<QuizAnswer> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: widget.color ?? Theme.of(context).colorScheme.secondary,
      shape: (widget.isSelected)
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                  style: BorderStyle.solid,
                  color: Theme.of(context).colorScheme.outline,
                  width: 10),
            )
          : null,
      child: InkWell(
        splashColor: widget.color?.withAlpha(204), // 0.8 * 255
        highlightColor: widget.color?.withAlpha(153), // 0.6 * 255
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onTap as void Function()? ?? () {},
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
                  Center(
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
                  ),
                  Expanded(
                    child: Center(
                      child: AutoSizeText(
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
              );
            },
          ),
        ),
      ),
    );
  }
}
