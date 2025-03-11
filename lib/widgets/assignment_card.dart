import 'package:flutter/material.dart';

enum AssignmentState { notStarted, completed, missed }

class AssignmentCard extends StatelessWidget {
  const AssignmentCard({
    super.key,
    required this.assignmentName,
    required this.dueDate,
    this.onTap,
    this.assignmentState = AssignmentState.missed,
  });

  final String assignmentName;
  final DateTime dueDate;
  final VoidCallback? onTap;
  final AssignmentState assignmentState;

  @override
  Widget build(BuildContext context) {
    Color? stateColor = Colors.amberAccent;
    String stateText = "Not Started";
    switch (assignmentState) {
      case AssignmentState.notStarted:
        stateColor = Colors.amberAccent;
        break;
      case AssignmentState.completed:
        stateColor = Colors.greenAccent;
        stateText = "Completed";
        break;
      case AssignmentState.missed:
        stateColor = Colors.redAccent;
        stateText = "Missed";
        break;
    }

    return Card(
      elevation: 4,
      color: stateColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        splashColor: stateColor.withAlpha(240),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: 200,
            height: 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  assignmentName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                ),
                Text(
                  "Due: ${dueDate.month}/${dueDate.day}/${dueDate.year}, ${dueDate.hour % 12}:${dueDate.minute} ${dueDate.hour > 12 ? 'PM' : 'AM'}",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                ),
                Text(
                  "Status: $stateText",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                ),
                Expanded(
                    child: Center(
                  child: Text(
                    "0/0",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BasicAdditionCard extends StatelessWidget {
  const BasicAdditionCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
              width: 200,
              height: 150,
              child: Center(
                child: Icon(
                  Icons.add,
                  size: 50,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )),
        ),
      ),
    );
  }
}
