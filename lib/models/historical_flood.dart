enum FloodSeverity { critical, warning, advisory, normal }

class HistoricalFlood {
  final int id;
  final String date;
  final String typhoon;
  final FloodSeverity severity;
  final List<String> affectedZones;
  final String maxWaterLevel;
  final int casualties;
  final int displaced;
  final int durationHours;
  final String notes;

  const HistoricalFlood({
    required this.id,
    required this.date,
    required this.typhoon,
    required this.severity,
    required this.affectedZones,
    required this.maxWaterLevel,
    required this.casualties,
    required this.displaced,
    required this.durationHours,
    required this.notes,
  });

  String get severityLabel {
    switch (severity) {
      case FloodSeverity.critical: return 'CRITICAL';
      case FloodSeverity.warning:  return 'WARNING';
      case FloodSeverity.advisory: return 'ADVISORY';
      case FloodSeverity.normal:   return 'NORMAL';
    }
  }
}