import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: Image.network(
                "https://i.kym-cdn.com/entries/icons/mobile/000/032/632/No_No_He's_Got_A_Point_Banner.jpg")));
  }
}
