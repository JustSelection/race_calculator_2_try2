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
  
  // ✅ Ключи для управления состоянием экранов
  final _calculatorKey = GlobalKey<CalculatorScreenState>();
  final _profilesKey = GlobalKey<ProfilesScreenState>(); // ✅ Новый ключ

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CalculatorScreen(key: _calculatorKey),
          ProfilesScreen(
            key: _profilesKey, // ✅ Передаём ключ
            onCarSelected: () {
              // ✅ Синхронизируем калькулятор при изменении профиля
              _calculatorKey.currentState?.refreshCars();
              // ✅ И перезагружаем профили
              _profilesKey.currentState?.reloadData();
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: (i) {
          setState(() => _currentIndex = i);
          
          // ✅ При переключении на калькулятор — обновляем список авто
          if (i == 0) {
            _calculatorKey.currentState?.refreshCars();
          }
          
          // ✅ При переключении на профили — перезагружаем данные из хранилища
          if (i == 1) {
            _profilesKey.currentState?.reloadData();
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