import 'package:flutter/material.dart';
import 'calculator_screen.dart';
import 'profiles_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  // ✅ Публичный тип: CalculatorScreenState (без подчёркивания!)
  final _calculatorKey = GlobalKey<CalculatorScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CalculatorScreen(key: _calculatorKey),
          // ✅ onCarSelected (НЕ onProfileChanged!)
          ProfilesScreen(
            onCarSelected: () {
              final state = _calculatorKey.currentState;
              if (state != null) state.refreshCars();
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) {
            final state = _calculatorKey.currentState;
            if (state != null) state.refreshCars();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'Калькулятор'),
          BottomNavigationBarItem(icon: Icon(Icons.car_rental), label: 'Профили'),
        ],
      ),
    );
  }
}