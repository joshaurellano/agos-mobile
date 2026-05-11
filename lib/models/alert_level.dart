import 'package:flutter/material.dart';
import '../main.dart';

enum AlertLevelType { normal, advisory, warning, critical }

class AlertLevel {
  final String label;
  final Color color;
  final String description;
  final String action;
  final AlertLevelType type;

  const AlertLevel({
    required this.label,
    required this.color,
    required this.description,
    required this.action,
    required this.type,
  });

  static const Map<AlertLevelType, AlertLevel> levels = {
    AlertLevelType.normal: AlertLevel(
      label: 'Normal',
      color: AppColors.green,
      description: 'No significant flooding risk. Water levels within safe range.',
      action: 'No action required. Continue monitoring.',
      type: AlertLevelType.normal,
    ),
    AlertLevelType.advisory: AlertLevel(
      label: 'Advisory',
      color: AppColors.yellow,
      description: 'Elevated water levels. Minor flooding possible in low-lying areas.',
      action: 'Residents near waterways should be on alert.',
      type: AlertLevelType.advisory,
    ),
    AlertLevelType.warning: AlertLevel(
      label: 'Warning',
      color: AppColors.orange,
      description: 'Significant flooding expected. Zone 3 at high risk.',
      action: 'Prepare evacuation. Secure valuables. Monitor updates.',
      type: AlertLevelType.warning,
    ),
    AlertLevelType.critical: AlertLevel(
      label: 'Critical',
      color: AppColors.red,
      description: 'Severe flooding imminent. Immediate danger to life and property.',
      action: 'EVACUATE IMMEDIATELY. Proceed to designated evacuation centers.',
      type: AlertLevelType.critical,
    ),
  };

  static AlertLevelType fromWaterLevel(double level) {
    if (level >= 4.5) return AlertLevelType.critical;
    if (level >= 3.5) return AlertLevelType.warning;
    if (level >= 2.5) return AlertLevelType.advisory;
    return AlertLevelType.normal;
  }
}