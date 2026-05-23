import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/car_profile.dart';
import '../models/trip.dart';
import '../services/storage_service.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => CalculatorScreenState();
}

class CalculatorScreenState extends State<CalculatorScreen> {
  final _dateCtrl = TextEditingController();
  final _startOdoCtrl = TextEditingController();
  final _endOdoCtrl = TextEditingController();
  final _fuelDepCtrl = TextEditingController();
  final _fuelAddCtrl = TextEditingController();

  List<CarProfile> _cars = [];
  CarProfile? _selectedCar;
  String? _resultText;
  Trip? _pendingTrip;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('dd.MM.yyyy').format(DateTime.now());
    _loadCars();
  }

  @override
  void dispose() {
    _dateCtrl.dispose(); _startOdoCtrl.dispose(); _endOdoCtrl.dispose();
    _fuelDepCtrl.dispose(); _fuelAddCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCars() async {
    final cars = await StorageService.loadProfiles();
    if (mounted) setState(() => _cars = cars);
  }

  // ✅ ПУБЛИЧНЫЙ метод для обновления извне
  void refreshCars() {
    _loadCars().then((_) {
      if (!mounted) return;
      if (_selectedCar != null) {
        // ✅ Находим объект в новом списке по id
        final found = _cars.firstWhere(
          (c) => c.id == _selectedCar!.id,
          orElse: () => _selectedCar!,
        );
        // Если авто удалён — сбрасываем
        if (!_cars.any((c) => c.id == _selectedCar!.id)) {
          _selectedCar = null;
          _startOdoCtrl.clear();
          _fuelDepCtrl.clear();
        } else {
          _selectedCar = found;
        }
        setState(() {});
      }
    });
  }

  // ✅ Helper: возвращает объект ИЗ списка или null
  CarProfile? _getValidSelectedCar() {
    if (_selectedCar == null) return null;
    for (final car in _cars) {
      if (car.id == _selectedCar!.id) return car;
    }
    return null;
  }

  Future<void> _onCarSelected(CarProfile? car) async {
    if (car == null || !mounted) return;
    _selectedCar = car;
    final trips = await StorageService.loadTrips(car.brand, car.plate);
    if (!mounted) return;
    final last = trips.isNotEmpty ? trips.first : null;
    _startOdoCtrl.text = (last?.endOdo ?? car.currentOdo).toString();
    _fuelDepCtrl.text = (last?.remaining ?? 0.0).toString();
    setState(() {});
  }

  void _calculate() {
    final start = double.tryParse(_startOdoCtrl.text);
    final end = double.tryParse(_endOdoCtrl.text);
    final fuelDep = double.tryParse(_fuelDepCtrl.text);
    final fuelAdd = double.tryParse(_fuelAddCtrl.text);
    final cons = _selectedCar?.consumption;

    if (start == null || end == null || fuelDep == null || fuelAdd == null || cons == null || end <= start) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните все поля корректно')));
      return;
    }

    final distance = end - start;
    double consumed = (distance / 100) * cons;
    double remaining = fuelDep + fuelAdd - consumed;
    double finalEnd = end;

    if (remaining < 3.0) {
      final maxDist = (fuelDep + fuelAdd - 3.0) * (100 / cons);
      finalEnd = start + maxDist;
      remaining = 3.0;
      consumed = fuelDep + fuelAdd - 3.0;
    }

    _pendingTrip = Trip(
      id: _uuid.v4(),
      date: DateFormat('dd.MM.yyyy').parse(_dateCtrl.text),
      startOdo: start, endOdo: finalEnd,
      fuelDeparture: fuelDep, fuelAdded: fuelAdd,
      remaining: remaining, distance: finalEnd - start, consumption: cons,
    );

    _resultText = '''--- Результат ---
Дата: ${DateFormat('dd.MM.yyyy').format(_pendingTrip!.date)}
Кон. пробег: ${_pendingTrip!.endOdo.toStringAsFixed(0)} км
Остаток: ${_pendingTrip!.remaining.toStringAsFixed(2)} л
Заправлено: ${_pendingTrip!.fuelAdded.toStringAsFixed(2)} л

--- Дополнительно ---
Нач. пробег: ${_pendingTrip!.startOdo.toStringAsFixed(0)} км
Кон. пробег: ${_pendingTrip!.endOdo.toStringAsFixed(0)} км
Дистанция: ${_pendingTrip!.distance.toStringAsFixed(1)} км
Расход: ${_pendingTrip!.consumption.toStringAsFixed(0)} л/100км
Топливо на момент выезда: ${_pendingTrip!.fuelDeparture.toStringAsFixed(2)} л
Остаток топлива: ${_pendingTrip!.remaining.toStringAsFixed(2)} л''';
    setState(() {});
  }

  void _reset() {
    _startOdoCtrl.clear(); _endOdoCtrl.clear();
    _fuelDepCtrl.clear(); _fuelAddCtrl.clear();
    _selectedCar = null; _pendingTrip = null; _resultText = null;
    _dateCtrl.text = DateFormat('dd.MM.yyyy').format(DateTime.now());
    setState(() {});
  }

  Future<void> _save() async {
    if (_pendingTrip == null || _selectedCar == null || !mounted) return;
    await StorageService.saveTrip(_selectedCar!.brand, _selectedCar!.plate, _pendingTrip!);
    
    if (!mounted) return;
    final idx = _cars.indexWhere((c) => c.id == _selectedCar!.id);
    if (idx != -1) {
      _cars[idx].currentOdo = _pendingTrip!.endOdo;
      await StorageService.saveProfiles(_cars);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено')));
    setState(() { _pendingTrip = null; _resultText = null; });
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: TextField(
      controller: ctrl, keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Калькулятор рейса')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('Дата', _dateCtrl, hint: 'dd.MM.yyyy'),
            
            // ✅ FIX: value берётся ТОЛЬКО из списка _cars
            DropdownButtonFormField<CarProfile>(
              // ignore: deprecated_member_use
              value: _getValidSelectedCar(),
              hint: const Text('Автомобиль'),
              items: _cars.map((c) => DropdownMenuItem(value: c, child: Text('${c.brand} ${c.plate}'))).toList(),
              onChanged: _onCarSelected,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Автомобиль'),
            ),
            
            const SizedBox(height: 12),
            _field('Начальный пробег (км)', _startOdoCtrl),
            _field('Конечный пробег (км)', _endOdoCtrl),
            _field('Топливо в баке на выезде (л)', _fuelDepCtrl),
            _field('Заправлено топлива (л)', _fuelAddCtrl),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: _calculate, child: const Text('Рассчитать'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: _reset, child: const Text('Сброс'))),
              ],
            ),
            if (_resultText != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: SelectableText(_resultText!, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _save, child: const Text('Сохранить')),
            ]
          ],
        ),
      ),
    );
  }
}