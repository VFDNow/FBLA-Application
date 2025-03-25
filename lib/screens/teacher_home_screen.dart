import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fbla_application/screens/class_home_screen.dart';
import 'package:fbla_application/screens/teacher_class_home_screen.dart'; // Add this import
import 'package:fbla_application/utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide NavigationDrawer;
import 'package:fbla_application/widgets/nav-drawer.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  Map<String, dynamic>? userData;
  Map<String, List<Map<String, dynamic>>> groupedClasses = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (FirebaseAuth.instance.currentUser == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Load user data
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get();
    
    // Load all classes where current user is the owner
    QuerySnapshot classesSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .where('owner', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .get();
    
    // Group classes by name
    Map<String, List<Map<String, dynamic>>> classes = {};
    
    for (var doc in classesSnapshot.docs) {
      Map<String, dynamic> classData = doc.data() as Map<String, dynamic>;
      classData['classId'] = doc.id; // Add document ID to the data
      
      String className = classData['className'] ?? 'Unnamed Class';
      
      if (!classes.containsKey(className)) {
        classes[className] = [];
      }
      
      classes[className]!.add(classData);
    }
    
    setState(() {
      userData = userDoc.data() as Map<String, dynamic>?;
      groupedClasses = classes;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: <Widget>[
              // Header Banner
              Container(
                width: double.infinity,
                height: 200,
                color: Theme.of(context).colorScheme.primary,
                child: Center(
                  child: Text(
                    'Welcome, ${userData?['userFirst'] ?? 'Teacher'}!',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
              ),
              
              // Classes Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modified heading without the create class button
                    Text(
                      'My Classes',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    SizedBox(height: 16),
                    
                    // Class list
                    if (groupedClasses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Text(
                            'No classes yet. Create your first class!',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: groupedClasses.length,
                        itemBuilder: (context, index) {
                          String className = groupedClasses.keys.elementAt(index);
                          List<Map<String, dynamic>> classItems = groupedClasses[className]!;
                          
                          // If there's only one hour for this class name
                          if (classItems.length == 1) {
                            Map<String, dynamic> classData = classItems.first;
                            return Card(
                              margin: EdgeInsets.only(bottom: 12.0),
                              child: ListTile(
                                leading: Icon(
                                  Constants.subjectIconStringMap[classData['classIcon']] ?? Icons.book,
                                  size: 36,
                                ),
                                title: Text(className),
                                subtitle: Text('Hour: ${classData['classHour'] ?? 'N/A'}'),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    Constants.classHomeRoute,
                                    arguments: ClassHomeArgs(classData['classId']),
                                  );
                                },
                              ),
                            );
                          } 
                          // If there are multiple hours for this class name
                          else {
                            return Card(
                              margin: EdgeInsets.only(bottom: 12.0),
                              child: ExpansionTile(
                                leading: Icon(
                                  Constants.subjectIconStringMap[classItems.first['classIcon']] ?? Icons.book,
                                  size: 36,
                                ),
                                title: Text(className),
                                subtitle: Text('${classItems.length} sections'),
                                // Replace onTap with onExpansionChanged
                                onExpansionChanged: (isExpanded) {
                                  if (!isExpanded) {
                                    // Only navigate when clicking to expand, not to collapse
                                    // Navigate directly to teacher class home
                                    List<String> sectionIds =
                                        classItems.map((section) => section['classId'].toString()).toList();
                                    String? baseClassId = classItems.first['baseClassId'];
                                    
                                    Navigator.pushNamed(
                                      context,
                                      '/teacher_class_home',
                                      arguments: TeacherClassHomeArgs(
                                          className, sectionIds, classItems.first['classIcon'], 
                                          baseClassId: baseClassId),
                                    );
                                  }
                                },
                                children: classItems.map((classData) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.only(left: 72.0, right: 16.0),
                                    title: Text('Hour: ${classData['classHour'] ?? 'N/A'}'),
                                    subtitle: Text(classData['classDesc'] ?? ''),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        Constants.classHomeRoute,
                                        arguments: ClassHomeArgs(classData['classId']),
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Add Extended FAB with tertiary color
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, Constants.createClassRoute);
        },
        icon: Icon(Icons.add),
        label: Text('Create Class'),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        foregroundColor: Theme.of(context).colorScheme.onTertiary,
      ),
      drawer: const NavigationDrawer(),
    );
  }
}
