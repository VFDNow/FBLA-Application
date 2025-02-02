import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NavigationDrawer extends StatelessWidget {
  const NavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Drawer(child: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Drawer(child: Center(child: Text('No data available')));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;

          return Drawer(
              child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildHeader(context, userData),
                Divider(color: Theme.of(context).dividerColor),
                buildMenuItems(context)
              ],
            ),
          ));
        });
  }
}

Widget buildHeader(BuildContext context, Map<String, dynamic> userData) =>
    Container(
      color: Theme.of(context).primaryColor,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primary,
            child: Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 100,
                    backgroundImage: NetworkImage(
                        Constants.profilePictureRoute +
                            userData['User Image Seed']),
                  ),
                  const SizedBox(height: 10),
                  // ignore: prefer_interpolation_to_compose_strings
                  Text(userData['User First'] + " " + userData['User Last'],
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary)),
                  const SizedBox(height: 10),
                  Text(userData['User Type'],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary))
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
          onTap: () =>
              Navigator.pushReplacementNamed(context, Constants.homeRoute),
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
