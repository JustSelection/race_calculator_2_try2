class CarProfile {
  final String id;
  String brand;
  String plate;
  double consumption;
  double currentOdo;
  double fuelInTank;

  CarProfile({
    required this.id,
    required this.brand,
    required this.plate,
    required this.consumption,
    required this.currentOdo,
    this.fuelInTank = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'brand': brand, 'plate': plate,
    'consumption': consumption, 'currentOdo': currentOdo,
    'fuelInTank': fuelInTank,
  };

  factory CarProfile.fromJson(Map<String, dynamic> json) => CarProfile(
    id: json['id'] as String,
    brand: json['brand'] as String,
    plate: json['plate'] as String,
    consumption: (json['consumption'] as num).toDouble(),
    currentOdo: (json['currentOdo'] as num).toDouble(),
    fuelInTank: json['fuelInTank'] != null 
        ? (json['fuelInTank'] as num).toDouble() 
        : 0.0,
  );
}