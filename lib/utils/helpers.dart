// lib/utils/helpers.dart
import 'package:smart_fireguard/models/notification_type.dart';

Map<String, double> fuzzifyTemp(double temp) {
  double low = 0, med = 0, high = 0;
  if (temp <= 25) low = 1;
  else if (temp > 25 && temp < 30) low = (30 - temp) / 5;
  if (temp >= 25 && temp <= 45) med = (temp <= 35) ? (temp - 25) / 10 : (45 - temp) / 10;
  if (temp >= 35) high = (temp >= 55) ? 1 : (temp - 35) / 20;
  return {
    'Low': low.clamp(0, 1),
    'Medium': med.clamp(0, 1),
    'High': high.clamp(0, 1),
  };
}

Map<String, double> fuzzifySmoke(double smoke) {
  double clean = 0, mod = 0, smoky = 0;
  if (smoke <= 200) clean = 1;
  else if (smoke > 200 && smoke < 300) clean = (300 - smoke) / 100;
  if (smoke >= 200 && smoke <= 300) mod = (smoke - 200) / 100;
  else if (smoke > 300 && smoke <= 400) mod = 1;
  else if (smoke > 400 && smoke <= 500) mod = (500 - smoke) / 100;
  if (smoke > 400 && smoke <= 500) smoky = (smoke - 400) / 100;
  else if (smoke > 500) smoky = 1;
  return {
    'Clean': clean.clamp(0, 1),
    'Moderate': mod.clamp(0, 1),
    'Smoky': smoky.clamp(0, 1),
  };
}

String? determineNotificationType(
    Map<String, double> fuzzyTemp,
    Map<String, double> fuzzySmoke,
    bool flame,
) {
  if ((fuzzySmoke['Smoky'] ?? 0) >= 0.7 && (fuzzyTemp['High'] ?? 0) >= 0.7) {
    return NotificationType.emergency.value;
  }
  if (flame) {
    return NotificationType.flameDetected.value;
  }
  if ((fuzzySmoke['Smoky'] ?? 0) >= 0.7) {
    return NotificationType.smokeDetected.value;
  }
  return null;
}

double? parseDouble(dynamic val) {
  if (val == null) return null;
  if (val is double) return val;
  if (val is int) return val.toDouble();
  return double.tryParse(val.toString());
}

String nowDate() {
  final now = DateTime.now();
  return '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.year}';
}

String nowTime() {
  final now = DateTime.now();
  int hour = now.hour;
  final ampm = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12 == 0 ? 12 : hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  return '$hour:$minute $ampm';
}