enum SourceStatus { live, delayed, simulated }
enum SourceType   { rainfall, waterLevel, sensor, local, advisory, lgu }

class DataSource {
  final String name;
  final SourceStatus status;
  final String lastUpdate;
  final SourceType type;

  const DataSource({
    required this.name,
    required this.status,
    required this.lastUpdate,
    required this.type,
  });

  String get statusLabel {
    switch (status) {
      case SourceStatus.live:      return 'Live';
      case SourceStatus.delayed:   return 'Delayed';
      case SourceStatus.simulated: return 'Simulated';
    }
  }

  String get typeIcon {
    switch (type) {
      case SourceType.rainfall:   return '🌧';
      case SourceType.waterLevel: return '💧';
      case SourceType.sensor:     return '📡';
      case SourceType.local:      return '🏘';
      case SourceType.advisory:   return '📢';
      case SourceType.lgu:        return '🏛';
    }
  }
}