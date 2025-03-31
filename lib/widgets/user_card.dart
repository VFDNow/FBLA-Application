import 'package:fbla_application/utils/constants.dart';
import 'package:flutter/material.dart';

class UserCard extends StatelessWidget {
  final String name;
  final String icon;

  const UserCard({super.key, required this.name, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Center(
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundImage: Image.network(
                  Constants.profilePictureRoute + icon,
                ).image,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(name,
                  softWrap: false,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      overflow: TextOverflow.fade)),
            ),
          ],
        ),
      ),
    );
  }
}
