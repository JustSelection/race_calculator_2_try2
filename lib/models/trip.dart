class Trip {
  final String id;
  final DateTime date;
  final double startOdo;
  final double endOdo;
  final double fuelDeparture;
  final double fuelAdded;
  final double remaining;
  final double distance;
  final double consumption;

  Trip({
    required this.id, required this.date,
    required this.startOdo, required this.endOdo,
    required this.fuelDeparture, required this.fuelAdded,
    required this.remaining, required this.distance, required this.consumption,
  });

  // ✅ Helper для округления до сотых
  static double _round2(double value) => double.parse(value.toStringAsFixed(2));

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(),
    'startOdo': _round2(startOdo), 'endOdo': _round2(endOdo),
    'fuelDeparture': _round2(fuelDeparture), 'fuelAdded': _round2(fuelAdded),
    'remaining': _round2(remaining), 'distance': _round2(distance),
    'consumption': consumption,
  };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    startOdo: _round2((json['startOdo'] as num).toDouble()),
    endOdo: _round2((json['endOdo'] as num).toDouble()),
    fuelDeparture: _round2((json['fuelDeparture'] as num).toDouble()),
    fuelAdded: _round2((json['fuelAdded'] as num).toDouble()),
    remaining: _round2((json['remaining'] as num).toDouble()),
    distance: _round2((json['distance'] as num).toDouble()),
    consumption: (json['consumption'] as num).toDouble(),
  );
}