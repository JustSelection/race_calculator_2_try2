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

  void refreshCars() {
    _loadCars().then((_) {
      if (!mounted) return;
      if (_selectedCar != null) {
        final found = _cars.firstWhere(
          (c) => c.id == _selectedCar!.id,
          orElse: () => _selectedCar!,
        );
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

  CarProfile? _getValidSelectedCar() {
    if (_selectedCar == null) return null;
    for (final car in _cars) {
      if (car.id == _selectedCar!.id) return car;
    }
    return null;
  }

  // ✅ Helper для округления до сотых
  double _round2(double value) => double.parse(value.toStringAsFixed(2));

Future<void> _onCarSelected(CarProfile? car) async {
  if (car == null || !mounted) return;
  _selectedCar = car;
  final trips = await StorageService.loadTrips(car.brand, car.plate);
  if (!mounted) return;
  final last = trips.isNotEmpty ? trips.first : null;
  
  _startOdoCtrl.text = _round2(last?.endOdo ?? car.currentOdo).toStringAsFixed(0);
  _fuelDepCtrl.text = _round2(last?.remaining ?? car.fuelInTank).toStringAsFixed(2); // ✅
  
  setState(() {});
}

  void _calculate() {
    // ✅ Округляем входные значения сразу после парсинга
    final start = _round2(double.tryParse(_startOdoCtrl.text) ?? 0);
    final end = _round2(double.tryParse(_endOdoCtrl.text) ?? 0);
    final fuelDep = _round2(double.tryParse(_fuelDepCtrl.text) ?? 0);
    final fuelAdd = _round2(double.tryParse(_fuelAddCtrl.text) ?? 0);
    final cons = _selectedCar?.consumption;

    if (start == 0 || end == 0 || fuelDep < 0 || fuelAdd < 0 || cons == null || end <= start) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните все поля корректно')));
      return;
    }

    final distance = _round2(end - start);
    double consumed = _round2((distance / 100) * cons);
    double remaining = _round2(fuelDep + fuelAdd - consumed);
    double finalEnd = end;

    if (remaining < 3.0) {
      final maxDist = _round2((fuelDep + fuelAdd - 3.0) * (100 / cons));
      finalEnd = _round2(start + maxDist);
      remaining = 3.0;
      consumed = _round2(fuelDep + fuelAdd - 3.0);
    }

    _pendingTrip = Trip(
      id: _uuid.v4(),
      date: DateFormat('dd.MM.yyyy').parse(_dateCtrl.text),
      startOdo: start,
      endOdo: finalEnd,
      fuelDeparture: fuelDep,
      fuelAdded: fuelAdd,
      remaining: remaining,
      distance: _round2(finalEnd - start),
      consumption: cons,
    );

    final fuelUsed = _round2(fuelDep + fuelAdd - remaining);

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
Затрачено топлива: ${fuelUsed.toStringAsFixed(2)} л
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

  final allProfiles = await StorageService.loadProfiles();
  final idx = allProfiles.indexWhere((c) => c.id == _selectedCar!.id);
  if (idx != -1) {
    allProfiles[idx].currentOdo = _pendingTrip!.endOdo;
    allProfiles[idx].fuelInTank = _pendingTrip!.remaining; // ✅ Обновляем топливо
    await StorageService.saveProfiles(allProfiles);
    
    setState(() {
      _cars = allProfiles;
      _pendingTrip = null;
      _resultText = null;
    });
  }
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено')));
  }
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