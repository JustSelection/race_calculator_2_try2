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
    if (!mounted) return;
    setState(() {
      _trips = trips;
      _loading = false;
      _computeAnalytics();
    });
  }

  void _computeAnalytics() {
    // ✅ Хэш для кэша
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

    // ✅ Актуальные данные из последнего рейса
    final lastTrip = _trips.first;
    final currentOdo = lastTrip.endOdo;
    final currentFuel = lastTrip.remaining;

    // ✅ Фактический расход: (полный бак − остаток) / дистанция × 100
    final totalDistance = _trips.fold(0.0, (sum, t) => sum + t.distance);
    final totalFullTank = _trips.fold(
      0.0,
      (sum, t) => sum + t.fuelDeparture + t.fuelAdded,
    );
    final totalRemaining = _trips.fold(0.0, (sum, t) => sum + t.remaining);
    final totalFuelActuallyUsed = (totalFullTank - totalRemaining).toDouble();

    final actualConsumption = totalDistance > 0
        ? ((totalFuelActuallyUsed / totalDistance) * 100).toDouble()
        : widget.profile.consumption;

    // ✅ Динамика бака: средний «полный бак» за последние 7 рейсов
    final last7 = _trips.take(7).toList();
    final avgFullTank = last7.isEmpty
        ? 0.0
        : (last7.fold(0.0, (sum, t) => sum + t.fuelDeparture + t.fuelAdded) /
                  last7.length)
              .toDouble();

    // ✅ Ожидаемый расход по путевке
    final expectedFuelForDistance =
        ((totalDistance / 100) * widget.profile.consumption).toDouble();

    // ✅ Разница
    final diffToWaybill = (totalFuelActuallyUsed - expectedFuelForDistance)
        .toDouble();

    _cacheHash = hash;
    _cachedData = AnalyticsData(
      actualConsumption: actualConsumption,
      avgFullTank: avgFullTank,
      diffToWaybill: diffToWaybill,
      totalTrips: _trips.length,
      totalDistance: totalDistance,
      totalFuelUsed: totalFuelActuallyUsed,
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
                  ]),
                  const SizedBox(height: 12),
                  _card('⛽ Фактические показатели', [
                    _row('Всего рейсов', '${_cachedData?.totalTrips ?? 0}'),
                    _row(
                      'Общая дистанция',
                      '${_cachedData?.totalDistance.toStringAsFixed(1) ?? '0'} км',
                    ),
                    _row(
                      'Фактический расход',
                      '${_cachedData?.actualConsumption.toStringAsFixed(2) ?? '0'} л/100км',
                      highlight: true,
                      color:
                          (_cachedData?.actualConsumption ?? 0) >
                              widget.profile.consumption
                          ? Colors.orange
                          : Colors.green,
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
                  _card('🔄 Динамика бака (7 рейсов)', [
                    _row(
                      'Разница с путевкой',
                      '${_cachedData?.diffToWaybill.toStringAsFixed(2) ?? '0'} л',
                      highlight: true,
                      color: (_cachedData?.diffToWaybill ?? 0) > 0
                          ? Colors.red
                          : Colors.blue,
                    ),
                    _row(
                      'Рекомендация',
                      _cachedData != null
                          ? (_cachedData!.diffToWaybill.abs() < 0.01
                                ? '✅ Баланс'
                                : _cachedData!.diffToWaybill > 0
                                ? '⚠️ Слить ${_cachedData!.diffToWaybill.toStringAsFixed(2)} л'
                                : '➕ Долить ${(-_cachedData!.diffToWaybill).toStringAsFixed(2)} л')
                          : '—',
                    ),
                  ]),
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
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: color,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    ),
  );
}

// ✅ Модель данных аналитики
class AnalyticsData {
  final double actualConsumption;
  final double avgFullTank; // ✅ средний «полный бак»
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
