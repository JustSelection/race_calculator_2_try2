class CarProfile {
  final String id;
  String brand;
  String plate;
  double consumption;
  double currentOdo;

  CarProfile({
    required this.id,
    required this.brand,
    required this.plate,
    required this.consumption,
    required this.currentOdo,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'brand': brand, 'plate': plate,
    'consumption': consumption, 'currentOdo': currentOdo,
  };

  factory CarProfile.fromJson(Map<String, dynamic> json) => CarProfile(
    id: json['id'] as String,
    brand: json['brand'] as String,
    plate: json['plate'] as String,
    consumption: (json['consumption'] as num).toDouble(),
    currentOdo: (json['currentOdo'] as num).toDouble(),
  );
}