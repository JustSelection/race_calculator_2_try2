import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/car_profile.dart';
import '../models/trip.dart';
import '../services/storage_service.dart';
import 'analytics_screen.dart';

class ProfilesScreen extends StatefulWidget {
  final VoidCallback? onCarSelected;
  const ProfilesScreen({super.key, this.onCarSelected});
  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  List<CarProfile> _profiles = [];
  CarProfile? _expandedProfile;
  List<Trip> _expandedTrips = [];
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await StorageService.loadProfiles();
    if (mounted) setState(() => _profiles = profiles);
  }

  Future<void> _loadTrips(CarProfile car) async {
    final trips = await StorageService.loadTrips(car.brand, car.plate);
    if (mounted) setState(() => _expandedTrips = trips);
  }

  void _showAddEditDialog([CarProfile? car]) {
    final brandCtrl = TextEditingController(text: car?.brand ?? '');
    final plateCtrl = TextEditingController(text: car?.plate ?? '');
    final consCtrl = TextEditingController(text: car?.consumption.toString() ?? '');
    final odoCtrl = TextEditingController(text: car?.currentOdo.toString() ?? '');
    final fuelCtrl = TextEditingController(text: (car?.fuelInTank ?? 0.0).toStringAsFixed(2));
    final isEdit = car != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Редактировать профиль' : 'Новый автомобиль'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Марка')),
              TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Госномер')),
              TextField(controller: consCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Расход (л/100км)')),
              TextField(controller: odoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Текущий пробег (км)')),
              TextField(controller: fuelCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Топливо в баке (л)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final brand = brandCtrl.text.trim();
              final plate = plateCtrl.text.trim();
              final cons = double.tryParse(consCtrl.text);
              final odo = double.tryParse(odoCtrl.text);
              final fuel = double.tryParse(fuelCtrl.text) ?? 0.0;
              if (brand.isEmpty || plate.isEmpty || cons == null || odo == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните все поля')));
                return;
              }
              final profile = isEdit
                  ? CarProfile(id: car.id, brand: brand, plate: plate, consumption: cons, currentOdo: odo, fuelInTank: fuel)
                  : CarProfile(id: _uuid.v4(), brand: brand, plate: plate, consumption: cons, currentOdo: odo, fuelInTank: fuel);
              
              final all = await StorageService.loadProfiles();
              if (isEdit) {
                final idx = all.indexWhere((p) => p.id == profile.id);
                if (idx != -1) all[idx] = profile;
              } else {
                all.add(profile);
              }
              await StorageService.saveProfiles(all);
              if (mounted) {
                Navigator.pop(context);
                _loadProfiles();
                widget.onCarSelected?.call();
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProfile(CarProfile car) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить профиль?'),
        content: Text('Удалить ${car.brand} ${car.plate} со всей историей?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    
    var all = await StorageService.loadProfiles();
    all.removeWhere((p) => p.id == car.id);
    await StorageService.saveProfiles(all);
    if (_expandedProfile?.id == car.id) setState(() => _expandedProfile = null);
    _loadProfiles();
    widget.onCarSelected?.call();
  }

  // ✅ Исправленный _deleteTrip с подтверждением и обработкой ошибок
  Future<void> _deleteTrip(CarProfile car, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить рейс?'),
        content: Text(
          'Удалить рейс от ${DateFormat('dd.MM.yyyy').format(trip.date)}?\n\n'
          '🛣 ${trip.startOdo.toStringAsFixed(0)} → ${trip.endOdo.toStringAsFixed(0)} км\n'
          '⛽ Остаток: ${trip.remaining.toStringAsFixed(2)} л',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    try {
      await StorageService.deleteTrip(car.brand, car.plate, trip.id);
      if (mounted) {
        _loadTrips(car);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Рейс удалён')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  void _toggleExpand(CarProfile car) {
    if (_expandedProfile?.id == car.id) {
      setState(() => _expandedProfile = null);
    } else {
      setState(() => _expandedProfile = car);
      _loadTrips(car);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профили автомобилей'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Аналитика',
            onPressed: _expandedProfile == null ? null : () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsScreen(profile: _expandedProfile!)));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _profiles.length,
        itemBuilder: (_, i) {
          final car = _profiles[i];
          final expanded = _expandedProfile?.id == car.id;
          return Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('${car.brand} ${car.plate}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Расход: ${car.consumption} л/100км • Пробег: ${car.currentOdo.toStringAsFixed(0)} км • Бак: ${car.fuelInTank.toStringAsFixed(2)} л'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showAddEditDialog(car)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProfile(car)),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                  onTap: () => _toggleExpand(car),
                ),
                if (expanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('История рейсов:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_expandedTrips.isEmpty)
                          const Text('Нет сохранённых рейсов', style: TextStyle(color: Colors.grey))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _expandedTrips.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),  
                            itemBuilder: (_, j) {
                              final trip = _expandedTrips[j];
                              return ListTile(
                                dense: true,
                                title: Text('📅 ${trip.date.day}.${trip.date.month}.${trip.date.year}'),
                                subtitle: Text('🛣 ${trip.startOdo.toStringAsFixed(0)} → ${trip.endOdo.toStringAsFixed(0)} км • ⛽ ${trip.remaining.toStringAsFixed(2)} л ост.'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                  onPressed: () => _deleteTrip(car, trip),
                                ),
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Детали рейса'),
                                    content: SelectableText('''Дата: ${trip.date.day}.${trip.date.month}.${trip.date.year}
Нач. пробег: ${trip.startOdo.toStringAsFixed(0)} км
Кон. пробег: ${trip.endOdo.toStringAsFixed(0)} км
Дистанция: ${trip.distance.toStringAsFixed(1)} км
Расход: ${trip.consumption.toStringAsFixed(0)} л/100км
Топливо на выезде: ${trip.fuelDeparture.toStringAsFixed(2)} л
Заправлено: ${trip.fuelAdded.toStringAsFixed(2)} л
Остаток: ${trip.remaining.toStringAsFixed(2)} л'''),
                                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}