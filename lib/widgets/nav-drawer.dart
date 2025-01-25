

import 'package:fbla_application/utils/constants.dart';
import 'package:flutter/material.dart';

class NavigationDrawer extends StatelessWidget{
  const NavigationDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildHeader(context),
            Divider(color: Theme.of(context).dividerColor),
            buildMenuItems(context)
          ],
        ),
      )
    );
  }
}

Widget buildHeader(BuildContext context) => Container(
  color: Theme.of(context).primaryColor,
  padding: EdgeInsets.only(
    top: MediaQuery.of(context).padding.top
  ),
  child: Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: Theme.of(context).primaryColor,
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.account_circle, size: 100, color: Colors.white),
              const SizedBox(height: 10),
              Text('User Name', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              Text('User Type', style: Theme.of(context).textTheme.bodySmall)
            ],
          ),
        ),
      ),
      const SizedBox(height: 10)
    ],
  ),
);


Widget buildMenuItems(BuildContext context) => Column(
  children: [
    ListTile(
      leading: Icon(Icons.home),
      title: const Text('Home'),
      onTap: () => Navigator.pushReplacementNamed(context, Constants.homeRoute),
    ),
    Divider(color: Theme.of(context).dividerColor),
    ListTile(
      leading: Icon(Icons.person),
      title: const Text('Profile'),
      onTap: () => Navigator.pushNamed(context, Constants.profileRoute),
    ),
    Divider(color: Theme.of(context).dividerColor)
  ],
);