import 'package:flutter/material.dart';

class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.className,
    required this.teacherName,
    required this.onTap,
  });

  final String className;
  final String teacherName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
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
                  className,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                ),
                Text(
                  teacherName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
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
