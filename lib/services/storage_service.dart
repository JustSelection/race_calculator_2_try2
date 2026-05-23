import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/car_profile.dart';
import '../models/trip.dart';

class StorageService {
  static Future<String> _root() async => (await getApplicationDocumentsDirectory()).path;

  static String get _profilesFile => '/Race Calculator/profiles.json';
  static Future<String> _tripsFile(String brand, String plate) async {
    final root = await _root();
    // Санитизация имени папки для совместимости с ОС
    final safe = '${brand.replaceAll(RegExp(r'[^a-zA-Z0-9а-яА-ЯёЁ]'), '_')}_${plate.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    return '$root/Race Calculator/Auto/$safe/trips.json';
  }

  static Future<List<CarProfile>> loadProfiles() async {
    final root = await _root();
    final file = File('$root$_profilesFile');
    if (!file.existsSync()) return [];
    return (jsonDecode(file.readAsStringSync()) as List).map((e) => CarProfile.fromJson(e)).toList();
  }

  static Future<void> saveProfiles(List<CarProfile> profiles) async {
    final root = await _root();
    final file = File('$root$_profilesFile');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(profiles.map((p) => p.toJson()).toList()));
  }

  static Future<List<Trip>> loadTrips(String brand, String plate) async {
    final path = await _tripsFile(brand, plate);
    final file = File(path);
    if (!file.existsSync()) return [];
    return (jsonDecode(file.readAsStringSync()) as List).map((e) => Trip.fromJson(e)).toList();
  }

  static Future<void> saveTrip(String brand, String plate, Trip trip) async {
    final path = await _tripsFile(brand, plate);
    final file = File(path);
    file.parent.createSync(recursive: true);
    
    List<Trip> trips = [];
    if (file.existsSync()) {
      trips = (jsonDecode(file.readAsStringSync()) as List).map((e) => Trip.fromJson(e)).toList();
    }
    
    // Идемпотентность: замена по ID
    trips.removeWhere((t) => t.id == trip.id);
    trips.add(trip);
    trips.sort((a, b) => b.date.compareTo(a.date));
    file.writeAsStringSync(jsonEncode(trips.map((t) => t.toJson()).toList()));
  }

  static Future<void> deleteTrip(String brand, String plate, String tripId) async {
    final path = await _tripsFile(brand, plate);
    final file = File(path);
    if (!file.existsSync()) return;
    final trips = (jsonDecode(file.readAsStringSync()) as List).map((e) => Trip.fromJson(e)).toList();
    trips.removeWhere((t) => t.id == tripId);
    file.writeAsStringSync(jsonEncode(trips.map((t) => t.toJson()).toList()));
  }
}