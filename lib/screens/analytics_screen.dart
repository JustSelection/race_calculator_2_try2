import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/car_profile.dart';
import '../models/trip.dart';
import '../services/storage_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final CarProfile profile;
  const AnalyticsScreen({super.key, required this.profile});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsData? _cachedData;
  String? _cacheHash;
  List<Trip> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final trips = await StorageService.loadTrips(
      widget.profile.brand,
      widget.profile.plate,
    );
    // Сортировка по дате от новых к старым
    trips.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {
      _trips = trips;
      _loading = false;
      _computeAnalytics();
    });
  }

  void _computeAnalytics() {
    final hash =
        '${_trips.length}_${_trips.fold(0.0, (s, t) => s + t.remaining).toStringAsFixed(2)}';
    if (_cacheHash == hash && _cachedData != null) return;

    if (_trips.isEmpty) {
      _cachedData = AnalyticsData(
        actualConsumption: widget.profile.consumption,
        avgFullTank: 0.0,
        diffToWaybill: 0.0,
        totalTrips: 0,
        totalDistance: 0.0,
        totalFuelUsed: 0.0,
        currentOdo: widget.profile.currentOdo,
        currentFuel: widget.profile.fuelInTank,
      );
      _cacheHash = hash;
      return;
    }

    final lastTrip = _trips.first; // Самый новый рейс
    final currentOdo = lastTrip.endOdo;
    final currentFuel = lastTrip.remaining;

    // Берем последние 7 рейсов (включая самый последний)
    final allRelevantTrips = _trips.take(7).toList();

    // Для расчета фактического расхода исключаем самый последний рейс
    final tripsForConsumption = allRelevantTrips.length > 1
        ? allRelevantTrips
              .skip(1)
              .toList() // Пропускаем первый (последний по времени)
        : [];

    // Общая дистанция за последние 5-7 рейсов (кроме последнего)
    final totalDistance = tripsForConsumption.fold(
      0.0,
      (sum, t) => sum + t.distance,
    );

    // Затраченное топливо за последние 5-7 рейсов (кроме последнего):
    // (топливо на выезде + заправлено) - топливо на въезде
    final totalFuelUsed = tripsForConsumption.fold(
      0.0,
      (sum, t) => sum + ((t.fuelDeparture + t.fuelAdded) - t.remaining),
    );

    // Фактический расход: (затрачено топлива) / (рейсовый пробег) * 100
    final actualConsumption = totalDistance > 0
        ? (totalFuelUsed / totalDistance * 100).toDouble()
        : widget.profile.consumption;

    // Средний "полный бак" за последние 5-7 рейсов (кроме последнего): (топливо на выезде + заправлено)
    final avgFullTank = tripsForConsumption.isEmpty
        ? 0.0
        : (tripsForConsumption.fold(
                    0.0,
                    (sum, t) => sum + t.fuelDeparture + t.fuelAdded,
                  ) /
                  tripsForConsumption.length)
              .toDouble();

    // Ожидаемое топливо по путевке за дни, использованные для расхода
    final expectedFuel = (totalDistance / 100) * widget.profile.consumption;

    // Разница с путевкой: затрачено - ожидаемо
    final diffToWaybill = totalFuelUsed - expectedFuel;

    _cacheHash = hash;
    _cachedData = AnalyticsData(
      actualConsumption: actualConsumption,
      avgFullTank: avgFullTank,
      diffToWaybill: diffToWaybill,
      totalTrips: _trips.length,
      totalDistance: totalDistance,
      totalFuelUsed: totalFuelUsed,
      currentOdo: currentOdo,
      currentFuel: currentFuel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Аналитика: ${widget.profile.brand} ${widget.profile.plate}',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadData();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _card('📊 Профиль', [
                    _row(
                      'Расход (по путевке)',
                      '${widget.profile.consumption.toStringAsFixed(1)} л/100км',
                    ),
                    _row(
                      'Пробег (текущий)',
                      '${_cachedData?.currentOdo.toStringAsFixed(0) ?? widget.profile.currentOdo.toStringAsFixed(0)} км',
                      highlight: true,
                    ),
                    _row(
                      'Топливо в баке',
                      '${_cachedData?.currentFuel.toStringAsFixed(2) ?? widget.profile.fuelInTank.toStringAsFixed(2)} л',
                    ),
                    if (widget.profile.fullTankCapacity > 0)
                      _row(
                        'Объем бака',
                        '${widget.profile.fullTankCapacity.toStringAsFixed(1)} л',
                        italic: true,
                      ),
                  ]),
                  const SizedBox(height: 12),
                  _card('⛽ Фактические показатели', [
                    _row('Всего рейсов', '${_cachedData?.totalTrips ?? 0}'),
                    _row(
                      'Общая дистанция',
                      '${_cachedData?.totalDistance.toStringAsFixed(1) ?? '0'} км',
                    ),
                    _row(
                      'Факт. расход',
                      _trips.length < 2
                          ? '${widget.profile.consumption.toStringAsFixed(1)} (мало данных)'
                          : '${_cachedData?.actualConsumption.toStringAsFixed(2)} л/100км',
                      highlight: true,
                      color: _trips.length < 2
                          ? Colors.grey
                          : ((_cachedData?.actualConsumption ?? 0) >
                                    widget.profile.consumption
                                ? Colors.orange
                                : Colors.green),
                    ),
                    _row(
                      'Затрачено топлива',
                      '${_cachedData?.totalFuelUsed.toStringAsFixed(2) ?? '0'} л',
                    ),
                    _row(
                      '«Полный бак» (сред.)',
                      '${_cachedData?.avgFullTank.toStringAsFixed(2) ?? '0'} л',
                      italic: true,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _card('🔄 Динамика бака (5-7 рейсов)', [
                    _row(
                      'Разница с путевкой',
                      '${_cachedData?.diffToWaybill.toStringAsFixed(2) ?? '0'} л',
                      highlight: true,
                      color: (_cachedData?.diffToWaybill ?? 0) > 0
                          ? Colors.red
                          : Colors.blue,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Рекомендация',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _cachedData != null
                                ? (_trips.length < 2
                                      ? '⚠️ Мало данных (нужно ≥2 рейса)'
                                      : _trips.length < 5
                                      ? '📊 Предварительно: ${_cachedData!.diffToWaybill.abs() < 0.5
                                            ? 'баланс'
                                            : _cachedData!.diffToWaybill > 0
                                            ? 'слить ~${_cachedData!.diffToWaybill.toStringAsFixed(1)} л'
                                            : 'долить ~${(-_cachedData!.diffToWaybill).toStringAsFixed(1)} л'}'
                                      : (_cachedData!.diffToWaybill.abs() < 0.01
                                            ? '✅ Баланс'
                                            : _cachedData!.diffToWaybill > 0
                                            ? '🛢️ Слить ${_cachedData!.diffToWaybill.toStringAsFixed(2)} л'
                                            : '➕ Долить ${(-_cachedData!.diffToWaybill).toStringAsFixed(2)} л'))
                                : '—',
                            style: TextStyle(
                              fontWeight: _trips.length >= 5
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _trips.length < 2
                                  ? Colors.grey
                                  : _trips.length < 5
                                  ? Colors.blue[400]
                                  : (_cachedData?.diffToWaybill ?? 0) > 0
                                  ? Colors.red
                                  : Colors.blue,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.yellow[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: Colors.orange[800],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Заправляйтесь до щелчка перед выездом (1 раз за рейс) — это повысит точность расчётов.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[800],
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_trips.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '🗂 Последние рейсы',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _trips.take(5).length,
                      itemBuilder: (_, i) {
                        final t = _trips[i];
                        final fullTank = t.fuelDeparture + t.fuelAdded;
                        final used = fullTank - t.remaining;
                        final tripConsumption = t.distance > 0
                            ? (used / t.distance * 100)
                            : 0;
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${DateFormat('dd.MM.yyyy').format(t.date)} • ${t.distance.toStringAsFixed(1)} км',
                          ),
                          subtitle: Text(
                            'Бак: ${fullTank.toStringAsFixed(1)} л → Расход: ${tripConsumption.toStringAsFixed(1)} л/100км',
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(),
          ...children,
        ],
      ),
    ),
  );

  Widget _row(
    String label,
    String value, {
    bool highlight = false,
    Color? color,
    bool italic = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    ),
  );
}

class AnalyticsData {
  final double actualConsumption;
  final double avgFullTank;
  final double diffToWaybill;
  final int totalTrips;
  final double totalDistance;
  final double totalFuelUsed;
  final double currentOdo;
  final double currentFuel;

  AnalyticsData({
    required this.actualConsumption,
    required this.avgFullTank,
    required this.diffToWaybill,
    required this.totalTrips,
    required this.totalDistance,
    required this.totalFuelUsed,
    required this.currentOdo,
    required this.currentFuel,
  });
}
