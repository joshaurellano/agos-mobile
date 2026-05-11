import 'package:flutter/material.dart';
import '../main.dart';

enum FloodRisk { low, moderate, high, critical }

class FloodZone {
  final String id;
  final String name;
  final FloodRisk risk;
  final int households;

  const FloodZone({
    required this.id,
    required this.name,
    required this.risk,
    required this.households,
  });

  Color get color {
    switch (risk) {
      case FloodRisk.low:      return AppColors.green;
      case FloodRisk.moderate: return AppColors.yellow;
      case FloodRisk.high:     return AppColors.orange;
      case FloodRisk.critical: return AppColors.red;
    }
  }

  String get riskLabel {
    switch (risk) {
      case FloodRisk.low:      return 'LOW';
      case FloodRisk.moderate: return 'MODERATE';
      case FloodRisk.high:     return 'HIGH';
      case FloodRisk.critical: return 'CRITICAL';
    }
  }

  int get estimatedResidents => (households * 4.2).round();
}