import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const RaceCalculatorApp());

class RaceCalculatorApp extends StatelessWidget {
  const RaceCalculatorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Race Calculator 2.0',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}