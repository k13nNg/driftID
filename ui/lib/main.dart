import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const DriftIDApp());
}

class DriftIDApp extends StatelessWidget {
  const DriftIDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriftID',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const HomeScreen(),
    );
  }
}
