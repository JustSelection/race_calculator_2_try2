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

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(),
    'startOdo': startOdo, 'endOdo': endOdo,
    'fuelDeparture': fuelDeparture, 'fuelAdded': fuelAdded,
    'remaining': remaining, 'distance': distance, 'consumption': consumption,
  };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    startOdo: (json['startOdo'] as num).toDouble(),
    endOdo: (json['endOdo'] as num).toDouble(),
    fuelDeparture: (json['fuelDeparture'] as num).toDouble(),
    fuelAdded: (json['fuelAdded'] as num).toDouble(),
    remaining: (json['remaining'] as num).toDouble(),
    distance: (json['distance'] as num).toDouble(),
    consumption: (json['consumption'] as num).toDouble(),
  );
}