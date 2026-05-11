import 'dart:math';
import '../models/data_source.dart';
import '../models/flood_zone.dart';
import '../models/historical_flood.dart';
import '../models/notification_log.dart';
import '../models/weather_forecast.dart';

class MockDataService {
  static final _rng = Random();

  // ── Water Level ──────────────────────────────────────────────
  static List<Map<String, dynamic>> generateWaterLevelData() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> hours = [];
    for (int i = 23; i >= 0; i--) {
      final time = now.subtract(Duration(hours: i));
      final baseLevel = 1.8;
      final variance = sin((23 - i) * 0.4) * 0.6 + _rng.nextDouble() * 0.3;
      hours.add({
        'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        'level': double.parse((baseLevel + variance).toStringAsFixed(2)),
      });
    }
    hours[22]['level'] = 3.1;
    hours[23]['level'] = 3.4;
    return hours;
  }

  // ── Rainfall ─────────────────────────────────────────────────
  static List<Map<String, dynamic>> generateRainfallData() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> data = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      data.add({
        'date': '${_monthAbbr(date.month)} ${date.day}',
        'rainfall': double.parse((_rng.nextDouble() * 40 + 5).toStringAsFixed(1)),
      });
    }
    data[5]['rainfall'] = 62.3;
    data[6]['rainfall'] = 45.1;
    return data;
  }

  static List<Map<String, dynamic>> generateHourlyRainfallData() {
    final List<Map<String, dynamic>> data = List.generate(24, (i) => {
      'hour': '${i.toString().padLeft(2, '0')}:00',
      'rainfall': double.parse((_rng.nextDouble() * 18 + 1).toStringAsFixed(1)),
    });
    data[15]['rainfall'] = 28.3;
    data[16]['rainfall'] = 34.1;
    return data;
  }

  // ── Static Data ───────────────────────────────────────────────
  static const List<FloodZone> floodZones = [
    FloodZone(id: 'Z1', name: 'Zone 1', risk: FloodRisk.low,      households: 234),
    FloodZone(id: 'Z2', name: 'Zone 2', risk: FloodRisk.moderate, households: 187),
    FloodZone(id: 'Z3', name: 'Zone 3', risk: FloodRisk.high,     households: 156),
    FloodZone(id: 'Z4', name: 'Zone 4', risk: FloodRisk.low,      households: 201),
  ];

  static const List<WeatherForecast> weatherForecast = [
    WeatherForecast(time: '6H',  condition: 'Heavy Rain',     icon: '⛈',  temp: '24°C', rainChance: 85, wind: '45 km/h'),
    WeatherForecast(time: '12H', condition: 'Moderate Rain',  icon: '🌧',  temp: '23°C', rainChance: 70, wind: '35 km/h'),
    WeatherForecast(time: '18H', condition: 'Light Rain',     icon: '🌦',  temp: '24°C', rainChance: 55, wind: '25 km/h'),
    WeatherForecast(time: '24H', condition: 'Cloudy',         icon: '☁️', temp: '25°C', rainChance: 30, wind: '20 km/h'),
    WeatherForecast(time: '36H', condition: 'Partly Cloudy',  icon: '⛅', temp: '26°C', rainChance: 20, wind: '18 km/h'),
    WeatherForecast(time: '48H', condition: 'Sunny',          icon: '☀️', temp: '28°C', rainChance: 10, wind: '15 km/h'),
    WeatherForecast(time: '72H', condition: 'Partly Cloudy',  icon: '⛅', temp: '27°C', rainChance: 25, wind: '20 km/h'),
  ];

  static const List<DataSource> dataSources = [
    DataSource(name: 'PAGASA Weather Station',       status: SourceStatus.live,      lastUpdate: '2 min ago',  type: SourceType.rainfall),
    DataSource(name: 'Bicol River Gauge Station',    status: SourceStatus.live,      lastUpdate: '5 min ago',  type: SourceType.waterLevel),
    DataSource(name: 'DOST-ASTI Flood Sensors',      status: SourceStatus.live,      lastUpdate: '1 min ago',  type: SourceType.sensor),
    DataSource(name: 'Local Barangay Sensor (Sim.)', status: SourceStatus.simulated, lastUpdate: 'Real-time',  type: SourceType.local),
    DataSource(name: 'OCD Region V Advisory',        status: SourceStatus.live,      lastUpdate: '15 min ago', type: SourceType.advisory),
    DataSource(name: 'LGU Naga City Reports',        status: SourceStatus.delayed,   lastUpdate: '45 min ago', type: SourceType.lgu),
  ];

  static const List<HistoricalFlood> historicalFloods = [
    HistoricalFlood(id: 1, date: 'November 2023', typhoon: 'Typhoon Kristine',        severity: FloodSeverity.critical, affectedZones: ['Zone 1','Zone 2','Zone 3'],            maxWaterLevel: '5.2m', casualties: 0, displaced: 312, durationHours: 18, notes: 'Bicol River overflowed. Evacuation of 312 families.'),
    HistoricalFlood(id: 2, date: 'August 2023',   typhoon: 'Typhoon Egay',            severity: FloodSeverity.warning,  affectedZones: ['Zone 2','Zone 3'],                    maxWaterLevel: '4.1m', casualties: 0, displaced: 148, durationHours: 11, notes: 'Flooding in low-lying areas. Preemptive evacuation conducted.'),
    HistoricalFlood(id: 3, date: 'October 2022',  typhoon: 'Typhoon Paeng',           severity: FloodSeverity.critical, affectedZones: ['Zone 1','Zone 2','Zone 3','Zone 4'],  maxWaterLevel: '6.0m', casualties: 2, displaced: 520, durationHours: 30, notes: 'Worst flooding in 5 years. All zones affected.'),
    HistoricalFlood(id: 4, date: 'July 2022',     typhoon: 'Tropical Storm Florita',  severity: FloodSeverity.advisory, affectedZones: ['Zone 3'],                             maxWaterLevel: '3.6m', casualties: 0, displaced: 45,  durationHours: 6,  notes: 'Localized flooding near Bicol River banks.'),
    HistoricalFlood(id: 5, date: 'December 2021', typhoon: 'Typhoon Odette',          severity: FloodSeverity.warning,  affectedZones: ['Zone 2','Zone 3'],                    maxWaterLevel: '4.3m', casualties: 0, displaced: 210, durationHours: 14, notes: 'Storm surge combined with river overflow.'),
  ];

  static List<NotificationLog> getNotificationLog() => [
    NotificationLog(id: 1, time: '10:32 AM', type: NotificationType.warning,  message: 'Water level at Bicol River reached 3.4m — Warning threshold approaching.', sentBy: 'System', read: false),
    NotificationLog(id: 2, time: '09:15 AM', type: NotificationType.advisory, message: 'Rainfall accumulation exceeded 40mm in the last 3 hours.',                   sentBy: 'System', read: false),
    NotificationLog(id: 3, time: '08:00 AM', type: NotificationType.info,     message: 'PAGASA forecast: Heavy rainfall expected 12-18 hours.',                      sentBy: 'Admin',  read: true),
    NotificationLog(id: 4, time: 'Yesterday 11:45 PM', type: NotificationType.normal, message: 'Water levels returned to normal. All clear.',                         sentBy: 'System', read: true),
    NotificationLog(id: 5, time: 'Yesterday 3:20 PM',  type: NotificationType.warning, message: 'Flash flood advisory for Bicol River basin.',                        sentBy: 'PAGASA', read: true),
    NotificationLog(id: 6, time: 'Yesterday 8:00 AM',  type: NotificationType.info,    message: 'Daily monitoring report generated.',                                 sentBy: 'System', read: true),
  ];

  static String _monthAbbr(int m) =>
      const ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m];
}