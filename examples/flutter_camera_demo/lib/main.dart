import 'package:flutter/material.dart';

import 'demo_screen.dart';

void main() => runApp(const CostcoTagDemoApp());

class CostcoTagDemoApp extends StatelessWidget {
  const CostcoTagDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Costco Price Tag Parser — Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const DemoScreen(),
    );
  }
}
