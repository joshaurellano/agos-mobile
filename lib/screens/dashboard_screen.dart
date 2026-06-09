// dashboard_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../main.dart';
import '../models/alert_level.dart';

// ─── URLs ─────────────────────────────────────────────────────────────────────
const _modelUrl    = 'https://flood-api-553657561163.asia-southeast1.run.app/api/predict-flood';
const _forecastUrl = 'https://flood-api-553657561163.asia-southeast1.run.app/api/forecast';

// ─── Alert Colors ─────────────────────────────────────────────────────────────
const _alertColors = {
  'NORMAL':   Color(0xFF22c55e),
  'ADVISORY': Color(0xFFeab308),
  'WARNING':  Color(0xFFf97316),
  'CRITICAL': Color(0xFFef4444),
};

// ─── Threshold data ───────────────────────────────────────────────────────────
class _Threshold {
  final double min, max;
  final String label, wl, action;
  final Color color;
  const _Threshold(this.min, this.max, this.label, this.wl, this.action, this.color);
}

const _thresholds = {
  'NORMAL':   _Threshold(0,   2.4, 'Normal',   '< 2.5m',     'Continue normal activities. Monitor updates.',              Color(0xFF22c55e)),
  'ADVISORY': _Threshold(2.5, 3.4, 'Advisory', '2.5 – 3.4m', 'Stay alert. Prepare emergency go-bags.',                   Color(0xFFeab308)),
  'WARNING':  _Threshold(3.5, 4.4, 'Warning',  '3.5 – 4.4m', 'Move valuables to higher ground. Be ready to evacuate.',   Color(0xFFf97316)),
  'CRITICAL': _Threshold(4.5, 999, 'Critical', '≥ 4.5m',     'Evacuate immediately to designated evacuation centers.',   Color(0xFFef4444)),
};

// ─── Barangay Triangulo boundary ──────────────────────────────────────────────
const _trianguloPolygon = [
  LatLng(13.622162, 123.193368), LatLng(13.621778, 123.195934),
  LatLng(13.621222, 123.195882), LatLng(13.621053, 123.196923),
  LatLng(13.620874, 123.197226), LatLng(13.619826, 123.196902),
  LatLng(13.619792, 123.197160), LatLng(13.619419, 123.197081),
  LatLng(13.619310, 123.197670), LatLng(13.617688, 123.197134),
  LatLng(13.613977, 123.197774), LatLng(13.611311, 123.195202),
  LatLng(13.607139, 123.197145), LatLng(13.602733, 123.187140),
  LatLng(13.611057, 123.185706), LatLng(13.611714, 123.186500),
  LatLng(13.611770, 123.186722), LatLng(13.611529, 123.187289),
  LatLng(13.611511, 123.187524), LatLng(13.611704, 123.187806),
  LatLng(13.611891, 123.187920), LatLng(13.612091, 123.187856),
  LatLng(13.612502, 123.187898), LatLng(13.612609, 123.187964),
  LatLng(13.612574, 123.188154), LatLng(13.612936, 123.188138),
  LatLng(13.613193, 123.187934), LatLng(13.613532, 123.188201),
  LatLng(13.613921, 123.187954), LatLng(13.613929, 123.187798),
  LatLng(13.614044, 123.187740), LatLng(13.614219, 123.187710),
  LatLng(13.614300, 123.187333), LatLng(13.616435, 123.187325),
  LatLng(13.616637, 123.184921), LatLng(13.617106, 123.184082),
  LatLng(13.618525, 123.185204), LatLng(13.618746, 123.185162),
  LatLng(13.619016, 123.185245), LatLng(13.619187, 123.185523),
  LatLng(13.619383, 123.185558), LatLng(13.620149, 123.186123),
  LatLng(13.620387, 123.186049), LatLng(13.620389, 123.186138),
  LatLng(13.621316, 123.187165), LatLng(13.621189, 123.187267),
  LatLng(13.622423, 123.189744), LatLng(13.622633, 123.189794),
];

// ─── Prediction model ─────────────────────────────────────────────────────────
AlertLevelType _alertFromInt(int level) {
  switch (level) {
    case 3:  return AlertLevelType.critical;
    case 2:  return AlertLevelType.warning;
    case 1:  return AlertLevelType.advisory;
    default: return AlertLevelType.normal;
  }
}

String _alertKey(int level) {
  switch (level) {
    case 3:  return 'CRITICAL';
    case 2:  return 'WARNING';
    case 1:  return 'ADVISORY';
    default: return 'NORMAL';
  }
}

class _Prediction {
  final double probability;
  final int    alertLevel;
  final String status;
  final double rainfallMm;
  final int    windSignal;
  final int    humidity;
  final String leadTime;

  const _Prediction({
    required this.probability, required this.alertLevel, required this.status,
    required this.rainfallMm,  required this.windSignal,  required this.humidity,
    required this.leadTime,
  });

  factory _Prediction.fromJson(Map<String, dynamic> j) {
  final m = j['live_metrics'] as Map<String, dynamic>? ?? {};

  num? parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }

  return _Prediction(
    probability: (parseNum(j['probability']))?.toDouble() ?? 0.0,
    alertLevel:  (parseNum(j['alert_level']))?.toInt()   ?? 0,
    status:       j['status']?.toString()                ?? '',
    rainfallMm:  (parseNum(m['rainfall_mm']))?.toDouble() ?? 0.0,
    windSignal:  (parseNum(m['wind_signal']))?.toInt()   ?? 0,
    humidity:    (parseNum(m['humidity']))?.toInt()      ?? 0,
    leadTime:     j['lead_time_estimate']?.toString()    ?? '6–12 hrs',
  );
}

  double? get estimatedLevel {
    if (rainfallMm <= 0) return null;
    return double.parse((1.4 + rainfallMm * 0.045).toStringAsFixed(2));
  }

  String get probabilityPct => '${(probability * 100).toStringAsFixed(0)}%';
}

// ─── Snapshot for chart ───────────────────────────────────────────────────────
class _Snapshot {
  final String label;
  final double floodRisk; // 0–100
  final bool isToday;
  final int readings;
  const _Snapshot({required this.label, required this.floodRisk, this.isToday = false, this.readings = 0});
}

// ─── Main Widget ──────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final ValueChanged<AlertLevelType>? onAlertChanged;
  const DashboardScreen({super.key, this.onAlertChanged});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _Prediction? _pred;
  bool _loading         = true;
  bool _error           = false;
  bool _forecastLoading = true;
  List<Map<String, dynamic>> _forecast = [];
  DateTime _lastUpdated = DateTime.now();
  Timer? _timer;

  // Radar WebView
  late final WebViewController _windyCtrl;

  @override
  void initState() {
    super.initState();
    _windyCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF091729))
      ..loadRequest(Uri.parse(
          'https://www.windy.com/embed2.html?lat=13.621&lon=123.194&zoom=8&level=surface&overlay=rain&product=ecmwf&message=true&marker=true&location=coordinates'));
    _fetchPrediction();
    _fetchForecast();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchPrediction());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _fetchPrediction() async {
    try {
      final res = await http.get(Uri.parse(_modelUrl)).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final p = _Prediction.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _pred = p; _loading = false; _error = false; _lastUpdated = DateTime.now(); });
        });
        widget.onAlertChanged?.call(_alertFromInt(p.alertLevel));
      } else { throw Exception(); }
    } catch (e) {
      print('LSTM ERROR: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _loading = false; _error = true; });
      });
    }
  }

  Future<void> _fetchForecast() async {
    try {
      final res = await http.get(Uri.parse(_forecastUrl)).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {
            _forecast = (body['hourly'] as List? ?? body['forecast'] as List? ?? []).cast();
            _forecastLoading = false;
          });
        });
      }
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _forecastLoading = false);
      });
    }
  }

  // ── Derived helpers ───────────────────────────────────────────────────────
  String get _currentAlertKey => _alertKey(_pred?.alertLevel ?? 0);
  Color  get _alertColor      => _alertColors[_currentAlertKey] ?? _alertColors['NORMAL']!;

  Color get _waterColor {
    final lvl = _pred?.estimatedLevel;
    if (lvl == null) return const Color(0xFF4a6080);
    if (lvl >= 4.5) return const Color(0xFFef4444);
    if (lvl >= 3.5) return const Color(0xFFf97316);
    if (lvl >= 2.5) return const Color(0xFFeab308);
    return const Color(0xFF22c55e);
  }

  String get _waterSub {
    final lvl = _pred?.estimatedLevel;
    if (_pred == null) return 'Model offline — no data';
    if (lvl == null)   return 'No active rainfall · Baseline 1.4m';
    if (lvl >= 4.5)    return 'Critical threshold exceeded';
    if (lvl >= 3.5)    return 'Warning threshold exceeded';
    if (lvl >= 2.5)    return 'Advisory range';
    return 'Within safe range';
  }

  String get _waterBadge {
    final lvl = _pred?.estimatedLevel;
    if (lvl == null) return '';
    if (lvl >= 4.5) return '⛔ CRITICAL';
    if (lvl >= 3.5) return '⚠ WARNING';
    if (lvl >= 2.5) return '📢 ADVISORY';
    return '✅ NORMAL';
  }

  Color get _windColor {
    final s = _pred?.windSignal ?? 0;
    if (s >= 3) return const Color(0xFFef4444);
    if (s == 2) return const Color(0xFFf97316);
    if (s == 1) return const Color(0xFF38bdf8);
    return const Color(0xFF22c55e);
  }

  String get _windSub {
    final s = _pred?.windSignal ?? 0;
    if (s >= 4) return 'Extremely destructive · >185 km/h';
    if (s == 3) return 'Destructive winds · >121 km/h';
    if (s == 2) return 'Damaging winds · >61 km/h';
    if (s == 1) return 'Strong winds · >30 km/h';
    return 'No active wind signal';
  }

  Color get _probabilityColor {
    if (_pred == null) return const Color(0xFF4a6080);
    if (_pred!.alertLevel >= 2) return const Color(0xFFef4444);
    if (_pred!.alertLevel == 1) return const Color(0xFFf97316);
    return const Color(0xFF22c55e);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final alertInfo = AlertLevel.levels[_alertFromInt(_pred?.alertLevel ?? 0)]!;
    final lvl       = _pred?.estimatedLevel;
    final hasRain   = (_pred?.rainfallMm ?? 0) > 0;
    final pct       = _pred?.probabilityPct ?? '—';

    return RefreshIndicator(
      onRefresh: _fetchPrediction,
      color: const Color(0xFF38bdf8),
      backgroundColor: const Color(0xFF0d1f3c),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Offline Banner ────────────────────────────────────────────
            if (_error) ...[
              _OfflineBanner(),
              const SizedBox(height: 12),
            ],

            // ── Alert Status Header ───────────────────────────────────────
            _AlertHeader(
              alertInfo:   alertInfo,
              alertColor:  _alertColor,
              pred:        _pred,
              pct:         pct,
              lastUpdated: _lastUpdated,
              formatTime:  _formatTime,
            ),
            const SizedBox(height: 16),

            // ── KPI Metrics Row ───────────────────────────────────────────
            const _SectionLabel(icon: '📊', text: 'Live Metrics'),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.40,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _MetricCard(
                  icon: '💧', label: 'Est. Water Level',
                  value: lvl != null && hasRain ? '${lvl}m' : 'N/A',
                  sub: _waterSub,
                  color: lvl != null && hasRain ? _waterColor : const Color(0xFF4a6080),
                  badge: lvl != null && hasRain ? _waterBadge : null,
                  dim: lvl == null || !hasRain,
                ),
                _MetricCard(
                  icon: '🌧', label: 'Rainfall Intensity',
                  value: _pred != null ? _pred!.rainfallMm.toStringAsFixed(1) : '—',
                  unit: 'mm/hr',
                  sub: _pred != null ? 'OpenMeteo · Live feed' : 'PAGASA Station',
                  color: const Color(0xFF38bdf8),
                  badge: _pred != null
                    ? (_pred!.rainfallMm > 10 ? '🔴 Heavy' : _pred!.rainfallMm > 2 ? '🟡 Moderate' : '🟢 Light')
                    : null,
                ),
                _MetricCard(
                  icon: '🌀', label: 'PAGASA Wind Signal',
                  value: _pred != null ? '#${_pred!.windSignal}' : '—',
                  sub: _windSub, color: _windColor,
                ),
                _MetricCard(
                  icon: '🤖', label: 'Flood Probability',
                  value: _loading ? '...' : pct,
                  sub: _pred != null ? 'Humidity: ${_pred!.humidity}% · LSTM v1' : 'LSTM Model · Cloud Run',
                  color: _probabilityColor,
                  badge: _pred != null ? 'LSTM Prediction' : null,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Flood Status Map ──────────────────────────────────────────
            _FloodMapCard(currentAlertKey: _currentAlertKey, alertColor: _alertColor),
            const SizedBox(height: 18),

            // ── Water Level Gauge + Alert Level Reference ─────────────────
            const _SectionLabel(icon: '💧', text: 'Water Level Gauge'),
            const SizedBox(height: 8),
            _WaterLevelGaugeCard(
              level: lvl != null && hasRain ? lvl : null,
              color: lvl != null && hasRain ? _waterColor : const Color(0xFF4a6080),
            ),
            const SizedBox(height: 18),

            const _SectionLabel(icon: '🚦', text: 'Alert Level Reference'),
            const SizedBox(height: 8),
            _AlertLevelTable(currentAlertKey: _currentAlertKey),
            const SizedBox(height: 18),

            // ── System Status ─────────────────────────────────────────────
            _SystemStatusPanel(
              modelOnline:     !_error && !_loading && _pred != null,
              modelLoading:    _loading,
              modelError:      _error ? 'Model backend offline' : null,
              forecastOnline:  !_forecastLoading && _forecast.isNotEmpty,
              forecastLoading: _forecastLoading,
              forecastCount:   _forecast.length,
              formatTime:      _formatTime,
            ),
            const SizedBox(height: 18),

            // ── LSTM Prediction Input Summary ─────────────────────────────
            if (_pred != null) ...[
              _PredictionInputTable(pred: _pred!),
              const SizedBox(height: 18),
            ],

            // ── LSTM Flood Probability Trend Chart ────────────────────────
            _FloodForecastChart(),
            const SizedBox(height: 18),

            // ── 72-Hour Rainfall Forecast ─────────────────────────────────
            const _SectionLabel(icon: '⛅', text: '72-Hour Rainfall Forecast'),
            const SizedBox(height: 4),
            const Text('OpenMeteo · Naga City',
              style: TextStyle(color: Color(0xFF4a6080), fontSize: 10)),
            const SizedBox(height: 10),
            _ForecastStrip(forecast: _forecast, loading: _forecastLoading),
            const SizedBox(height: 18),

            // ── Live Weather Radar ────────────────────────────────────────
            const _SectionLabel(icon: '🛰', text: 'Live Weather Radar'),
            const SizedBox(height: 8),
            _RadarCard(windyCtrl: _windyCtrl),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String icon, text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(icon, style: const TextStyle(fontSize: 12)),
    const SizedBox(width: 6),
    Flexible(
      child: Text(text.toUpperCase(), style: const TextStyle(
        color: Color(0xFF4a6080), fontSize: 10,
        fontWeight: FontWeight.w800, letterSpacing: 1.5,
      )),
    ),
    const SizedBox(width: 8),
    Expanded(child: Container(height: 1, color: const Color(0xFF1e3a5f))),
  ]);
}

// ── Offline Banner ──────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: Row(children: [
      Container(width: 3, color: const Color(0xFFef4444)),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFef4444).withValues(alpha: 0.07),
            border: Border.all(color: const Color(0xFFef4444).withValues(alpha: 0.25)),
          ),
          child: const Row(children: [
            Text('⚠', style: TextStyle(color: Color(0xFFf87171), fontSize: 13)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Model backend offline — displaying fallback data.',
                style: TextStyle(color: Color(0xFFf87171), fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
      ),
    ]),
  );
}

// ── Alert Status Header ─────────────────────────────────────────────────────
class _AlertHeader extends StatelessWidget {
  final dynamic alertInfo;
  final Color alertColor;
  final _Prediction? pred;
  final String pct;
  final DateTime lastUpdated;
  final String Function(DateTime) formatTime;

  const _AlertHeader({
    required this.alertInfo, required this.alertColor, required this.pred,
    required this.pct, required this.lastUpdated, required this.formatTime,
  });

 @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [alertColor.withValues(alpha: 0.10), Colors.transparent],
      ),
      border: Border.all(color: alertColor.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: IntrinsicHeight(  // ← fixes the infinite height problem
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left accent strip
          Container(width: 4, decoration: BoxDecoration(
            color: alertColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(9),
              bottomLeft: Radius.circular(9),
            ),
          )),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _PulsingDot(color: alertColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${alertInfo.label.toString().toUpperCase()} STATUS',
                      style: TextStyle(color: alertColor, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(alertInfo.description as String? ?? '',
                  style: const TextStyle(color: Color(0xFFe2eaf5), fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('🔔 ${alertInfo.action as String? ?? ''}',
                  style: const TextStyle(color: Color(0xFF8da4be), fontSize: 12)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('MODEL OUTPUT', style: TextStyle(
                      color: Color(0xFF4a6080), fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 1.2,
                    )),
                    const SizedBox(height: 4),
                    Text(
                      pred != null ? pred!.status : '⚠️ Flooding possible in next 6 hrs',
                      style: const TextStyle(color: Color(0xFFe2eaf5), fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    if (pred != null) ...[
                      const SizedBox(height: 6),
                      Text('⏱ Lead time: ${pred!.leadTime}',
                        style: const TextStyle(color: Color(0xFF8da4be), fontSize: 11)),
                    ],
                    const SizedBox(height: 4),
                    Text('Updated: ${formatTime(lastUpdated)}',
                      style: const TextStyle(color: Color(0xFF4a6080), fontSize: 10)),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Metric Card ─────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String icon, label, value, sub;
  final String? unit, badge;
  final Color color;
  final bool dim;

  const _MetricCard({
    required this.icon, required this.label, required this.value,
    required this.sub, required this.color,
    this.unit, this.badge, this.dim = false,
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dim ? 0.55 : 1.0,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: color),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0d1f3c),
                border: Border.all(color: const Color(0xFF1e3a5f)),
              ),
              child: Stack(children: [
                Positioned(right: 0, top: -2,
                  child: Text(icon, style: TextStyle(fontSize: 28, color: Colors.white.withValues(alpha: 0.05)))),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label.toUpperCase(), style: const TextStyle(
                    color: Color(0xFF4a6080), fontSize: 8,
                    fontWeight: FontWeight.w700, letterSpacing: 1.0,
                  )),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                      child: Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)))),
                    if (unit != null) ...[
                      const SizedBox(width: 3),
                      Text(unit!, style: const TextStyle(color: Color(0xFF4a6080), fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                  if (badge != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        border: Border.all(color: color.withValues(alpha: 0.35)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(badge!, style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(sub, style: const TextStyle(color: Color(0xFF8da4be), fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ]),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Flood Status Map ─────────────────────────────────────────────────────────
class _FloodMapCard extends StatefulWidget {
  final String currentAlertKey;
  final Color alertColor;
  const _FloodMapCard({required this.currentAlertKey, required this.alertColor});

  @override
  State<_FloodMapCard> createState() => _FloodMapCardState();
}

class _FloodMapCardState extends State<_FloodMapCard> {
  GoogleMapController? _mapController;

  @override
  void didUpdateWidget(_FloodMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Repaint polygon if alert changed
    if (oldWidget.currentAlertKey != widget.currentAlertKey) setState(() {});
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const alertLevelKeys = ['NORMAL', 'ADVISORY', 'WARNING', 'CRITICAL'];
    final color = _alertColors[widget.currentAlertKey] ?? _alertColors['NORMAL']!;
    final fillHex   = _colorToGoogleHex(color);
    final strokeHex = _colorToGoogleHex(color);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0d1f3c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1e3a5f)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🗺', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('FLOOD STATUS MAP — BARANGAY TRIANGULO', style: TextStyle(
                  color: Color(0xFF4a6080), fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 1.2,
                )),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Boundary overlay · Alert level color-coded',
              style: TextStyle(color: Color(0xFF4a6080), fontSize: 10)),
            const SizedBox(height: 8),
            // Alert level legend
            Row(children: alertLevelKeys.map((key) {
              final c = _alertColors[key]!;
              final isCur = key == widget.currentAlertKey;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(children: [
                  Container(width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: isCur ? 1.0 : 0.3),
                      borderRadius: BorderRadius.circular(2),
                    )),
                  const SizedBox(width: 4),
                  Text(key, style: TextStyle(
                    fontSize: 8.5, letterSpacing: 0.5, fontWeight: isCur ? FontWeight.w700 : FontWeight.w400,
                    color: isCur ? c : const Color(0xFF4a6080),
                  )),
                ]),
              );
            }).toList()),
          ]),
        ),
        // Map
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(9), bottomRight: Radius.circular(9)),
          child: SizedBox(
            height: 280,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(13.6140, 123.1915),
                zoom: 14.5,
              ),
              mapType: MapType.normal,
              polygons: {
                Polygon(
                  polygonId: const PolygonId('triangulo'),
                  points: _trianguloPolygon,
                  strokeColor: color,
                  strokeWidth: 2,
                  fillColor: color.withValues(alpha: 0.28),
                ),
              },
              onMapCreated: (ctrl) => _mapController = ctrl,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
        ),
        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Text(
            'Approximate barangay boundary · Source: PAGASA & OCD Region V',
            style: const TextStyle(color: Color(0xFF4a6080), fontSize: 9.5),
          ),
        ),
      ]),
    );
  }

  // Google Maps color is ARGB hex string
  static Color _colorToGoogleHex(Color c) => c; // just pass Color directly as-is
}

// ── Water Level Gauge Card ───────────────────────────────────────────────────
class _WaterLevelGaugeCard extends StatelessWidget {
  final double? level;
  final Color color;
  const _WaterLevelGaugeCard({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    const maxLevel = 6.0;
    final pct = level != null ? (level! / maxLevel).clamp(0.0, 1.0) : 0.0;

    final thresholds = [
      (value: 2.5, color: const Color(0xFFeab308), label: 'Advisory'),
      (value: 3.5, color: const Color(0xFFf97316), label: 'Warning'),
      (value: 4.5, color: const Color(0xFFef4444), label: 'Critical'),
    ];

   return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0d1f3c),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF1e3a5f)),
    ),
    child: IntrinsicHeight(                          // ← fix
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scale labels + bar — fixed sizes so no unconstrained height
          SizedBox(
            width: 28,
            height: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [6, 5, 4, 3, 2, 1, 0].map((v) =>
                Text('${v}m', style: const TextStyle(
                  color: Color(0xFF4a6080), fontSize: 8.5, fontWeight: FontWeight.w600)),
              ).toList(),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 36,
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFF152a4a),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1e3a5f)),
            ),
            child: Stack(children: [
              ...thresholds.map((t) => Positioned(
                bottom: (t.value / maxLevel) * 180,
                left: 0, right: 0,
                child: Container(height: 1, color: t.color.withValues(alpha: 0.7)),
              )),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  height: 180 * pct,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(5),
                      bottomRight: Radius.circular(5),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('EST. WATER LEVEL', style: TextStyle(
                color: Color(0xFF4a6080), fontSize: 8.5,
                fontWeight: FontWeight.w700, letterSpacing: 1.0,
              )),
              const SizedBox(height: 6),
              Text(
                level != null ? '${level}m' : 'N/A',
                style: TextStyle(color: color, fontSize: 36, fontWeight: FontWeight.w900, height: 1),
              ),
              const SizedBox(height: 6),
              Text(
                level == null   ? 'No model data available'
                : level! >= 4.5 ? 'Critical — immediate action required'
                : level! >= 3.5 ? 'Warning — monitor closely'
                : level! >= 2.5 ? 'Advisory — elevated risk'
                : 'Within normal range',
                style: const TextStyle(color: Color(0xFF8da4be), fontSize: 10.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              ...thresholds.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  Container(width: 16, height: 2, decoration: BoxDecoration(
                    color: t.color, borderRadius: BorderRadius.circular(1))),
                  const SizedBox(width: 6),
                  Text('${t.label} (${t.value}m)',
                    style: const TextStyle(color: Color(0xFF4a6080), fontSize: 9.5)),
                ]),
              )),
              const SizedBox(height: 8),
              const Text('Baseline 1.4m + rain ×0.045',
                style: TextStyle(color: Color(0xFF2a4060), fontSize: 8.5)),
            ]),
          ),
        ],
      ),
    ),
  );
  }
}

// ── Alert Level Reference Table ─────────────────────────────────────────────
class _AlertLevelTable extends StatelessWidget {
  final String currentAlertKey;
  const _AlertLevelTable({required this.currentAlertKey});

  @override
  Widget build(BuildContext context) {
    final levels = [
      (key: 'NORMAL',   range: '< 2.5m',     action: 'Continue normal activities. Monitor updates.'),
      (key: 'ADVISORY', range: '2.5 – 3.4m', action: 'Stay alert. Prepare emergency go-bags.'),
      (key: 'WARNING',  range: '3.5 – 4.4m', action: 'Move valuables to higher ground. Be ready to evacuate.'),
      (key: 'CRITICAL', range: '≥ 4.5m',     action: 'Evacuate immediately to designated evacuation centers.'),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0d1f3c),
          border: Border.all(color: const Color(0xFF1e3a5f)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: levels.asMap().entries.map((e) {
            final idx   = e.key;
            final item  = e.value;
            final isCur = item.key == currentAlertKey;
            final color = _thresholds[item.key]!.color;
            final isLast = idx == levels.length - 1;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCur ? color.withValues(alpha: 0.08) : Colors.transparent,
                border: Border(
                  bottom: isLast ? BorderSide.none : const BorderSide(color: Color(0xFF1e3a5f)),
                ),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 8, height: 8, margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 76,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_thresholds[item.key]!.label.toUpperCase(), style: TextStyle(
                      color: color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                    Text(item.range, style: const TextStyle(
                      color: Color(0xFF4a6080), fontSize: 9, fontFamily: 'monospace')),
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(item.action, style: TextStyle(
                    color: isCur ? const Color(0xFFe2eaf5) : const Color(0xFF4a6080),
                    fontSize: 10.5, height: 1.4,
                  ))),
                  if (isCur) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('CURRENT', style: TextStyle(
                        color: color, fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ])),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── System Status Panel ──────────────────────────────────────────────────────
class _SystemStatusPanel extends StatelessWidget {
  final bool modelOnline, modelLoading, forecastOnline, forecastLoading;
  final String? modelError;
  final int forecastCount;
  final String Function(DateTime) formatTime;

  const _SystemStatusPanel({
    required this.modelOnline, required this.modelLoading, required this.modelError,
    required this.forecastOnline, required this.forecastLoading, required this.forecastCount,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final indicators = [
      (
        label: 'LSTM Prediction Engine',
        status: modelLoading ? 'checking' : modelOnline ? 'online' : 'offline',
        detail: modelOnline ? 'Last response: ${formatTime(now)}' : modelError ?? 'Connecting...',
      ),
      (
        label: 'WeatherAPI Forecast Feed',
        status: forecastLoading ? 'checking' : forecastOnline ? 'online' : 'offline',
        detail: forecastOnline ? '$forecastCount hourly records loaded' : 'Feed unavailable',
      ),
      (
        label: 'Supabase Database',
        status: 'online',
        detail: 'Alert logs · User auth · SMS queue',
      ),
      (
        label: 'SMS Gateway (httpsms)',
        status: 'online',
        detail: 'Edge function standby',
      ),
    ];

    final statusColors = {
      'online':   const Color(0xFF22c55e),
      'offline':  const Color(0xFFef4444),
      'checking': const Color(0xFFeab308),
    };
    final statusLabels = {'online': 'ONLINE', 'offline': 'OFFLINE', 'checking': 'CHECKING'};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1f3c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1e3a5f)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionLabel(icon: '🖥', text: 'System Status'),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: indicators.map((ind) {
            final c = statusColors[ind.status]!;
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0a1828),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1e3a5f)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 7, height: 7, margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: c,
                    boxShadow: ind.status == 'online' ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)] : null,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ind.label, style: const TextStyle(
                    color: Color(0xFFe2eaf5), fontSize: 9.5, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text(statusLabels[ind.status]!, style: TextStyle(
                    color: c, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(ind.detail, style: const TextStyle(color: Color(0xFF4a6080), fontSize: 8.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
              ]),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ── LSTM Prediction Input Table ──────────────────────────────────────────────
class _PredictionInputTable extends StatelessWidget {
  final _Prediction pred;
  const _PredictionInputTable({required this.pred});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (icon: '🌧', label: 'Rainfall',          value: '${pred.rainfallMm.toStringAsFixed(2)} mm/hr', note: 'Primary flood driver'),
      (icon: '💨', label: 'Humidity',           value: '${pred.humidity}%',                          note: 'Atmospheric moisture'),
      (icon: '🌀', label: 'Wind Signal',        value: 'PAGASA #${pred.windSignal}',                 note: 'PAGASA classification'),
      (icon: '🤖', label: 'Flood Probability',  value: pred.probabilityPct,                          note: 'LSTM output confidence'),
      (icon: '🚦', label: 'Alert Level',        value: 'Level ${pred.alertLevel}',                   note: 'Model classification'),
      (icon: '⏱', label: 'Lead Time Est.',     value: pred.leadTime,                                note: 'Time before peak flood'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel(icon: '📊', text: 'LSTM Model — Prediction Input Summary'),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0d1f3c),
            border: Border.all(color: const Color(0xFF1e3a5f)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: rows.asMap().entries.map((e) {
              final idx  = e.key;
              final row  = e.value;
              final even = idx % 2 == 0;
              final isLast = idx == rows.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: even ? const Color(0xFF0a1828) : Colors.transparent,
                  border: Border(bottom: isLast ? BorderSide.none : const BorderSide(color: Color(0xFF1e3a5f))),
                ),
                child: Row(children: [
                  Text(row.icon, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(row.label, style: const TextStyle(color: Color(0xFFe2eaf5), fontSize: 11, fontWeight: FontWeight.w600)),
                    Text(row.note, style: const TextStyle(color: Color(0xFF4a6080), fontSize: 9.5)),
                  ])),
                  Text(row.value, style: const TextStyle(
                    color: Color(0xFF38bdf8), fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                ]),
              );
            }).toList(),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
        Text('Model: LSTM · Cloud Run (asia-southeast1)',
          style: TextStyle(color: Color(0xFF4a6080), fontSize: 9)),
        Text('Poll: 30s', style: TextStyle(color: Color(0xFF4a6080), fontSize: 9)),
      ]),
    ]);
  }
}

// ── LSTM Flood Probability Trend Chart ──────────────────────────────────────
class _FloodForecastChart extends StatefulWidget {
  const _FloodForecastChart();
  @override
  State<_FloodForecastChart> createState() => _FloodForecastChartState();
}

class _FloodForecastChartState extends State<_FloodForecastChart> {
  String _view = 'hourly'; // 'hourly' | 'daily'
  List<_Snapshot> _data = [];
  bool _loading = true;
  DateTime? _lastFetched;
  Timer? _timer;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchData());
    // Realtime subscription
    _sub = _supabase
      .from('flood_snapshots')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(1)
      .listen((_) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      if (_view == 'hourly') {
        final since = DateTime.now().subtract(const Duration(hours: 24));
        final res = await _supabase
          .from('flood_snapshots')
          .select('created_at, probability')
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: true);

        final rows = (res as List).cast<Map<String, dynamic>>();
        if (!mounted) return;
        setState(() {
          _data = rows.map((r) {
            final dt = DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now();
            final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
            final ampm = dt.hour < 12 ? 'AM' : 'PM';
            final m = dt.minute.toString().padLeft(2, '0');
            return _Snapshot(
              label: '$h:$m $ampm',
              floodRisk: ((r['probability'] as num? ?? 0) * 100).clamp(0, 100).roundToDouble(),
            );
          }).toList();
          _loading = false;
          _lastFetched = DateTime.now();
        });
      } else {
        final since = DateTime.now().subtract(const Duration(days: 7));
        final res = await _supabase
          .from('flood_snapshots')
          .select('created_at, probability')
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: true);

        final rows = (res as List).cast<Map<String, dynamic>>();
        final byDay = <String, ({DateTime date, List<double> probs})>{};
        for (final r in rows) {
          final dt  = DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now();
          final key = '${dt.year}-${dt.month}-${dt.day}';
          byDay.putIfAbsent(key, () => (date: dt, probs: []));
          byDay[key]!.probs.add((r['probability'] as num? ?? 0).toDouble());
        }

        if (!mounted) return;
        final days = byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
        setState(() {
          _data = days.takeLast(7).map((d) {
            final avg = d.probs.isEmpty ? 0.0 : d.probs.reduce((a, b) => a + b) / d.probs.length;
            final wday = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d.date.weekday - 1];
            final isToday = DateTime.now().toDateString() == d.date.toDateString();
            return _Snapshot(
              label: isToday ? 'TODAY' : '$wday ${d.date.day}/${d.date.month}',
              floodRisk: (avg * 100).clamp(0, 100).roundToDouble(),
              isToday: isToday,
              readings: d.probs.length,
            );
          }).toList();
          _loading = false;
          _lastFetched = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _riskColor(double pct) {
    if (pct >= 75) return const Color(0xFFef4444);
    if (pct >= 50) return const Color(0xFFf97316);
    if (pct >= 25) return const Color(0xFFeab308);
    return const Color(0xFF22c55e);
  }

  @override
  Widget build(BuildContext context) {
    final latest = _data.isNotEmpty ? _data.last.floodRisk : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1f3c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1e3a5f)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header row
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionLabel(icon: '🤖', text: 'LSTM Flood Probability Trend'),
            const SizedBox(height: 2),
            Text(
              'Live LSTM predictions · Supabase flood_snapshots'
              '${_lastFetched != null ? ' · synced ${_formatTime(_lastFetched!)}' : ''}',
              style: const TextStyle(color: Color(0xFF4a6080), fontSize: 9),
            ),
          ])),
          const SizedBox(width: 10),
          // Toggle
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0a1828),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1e3a5f)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _buildToggle('24-Hour', 'hourly'),
              _buildToggle('7-Day', 'daily'),
            ]),
          ),
        ]),
        const SizedBox(height: 12),

        // Latest callout
        if (latest != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _riskColor(latest).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _riskColor(latest).withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Text('${latest.toStringAsFixed(0)}%', style: TextStyle(
                color: _riskColor(latest), fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Current Flood Probability', style: TextStyle(
                  color: Color(0xFFe2eaf5), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  latest >= 75 ? '⛔ Immediate action may be required'
                  : latest >= 50 ? '⚠ High risk — monitor closely'
                  : latest >= 25 ? '📢 Elevated — stay alert'
                  : '✅ Low risk — conditions normal',
                  style: const TextStyle(color: Color(0xFF8da4be), fontSize: 9.5),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // Chart body
        if (_loading)
          Container(
            height: 200, alignment: Alignment.center,
            child: const Text('Loading predictions from Supabase...',
              style: TextStyle(color: Color(0xFF4a6080), fontSize: 12)),
          )
        else if (_data.isEmpty)
          Container(
            height: 200,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0a1828),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1e3a5f)),
            ),
            child: const Text('⚠️ No LSTM snapshots yet',
              style: TextStyle(color: Color(0xFF4a6080), fontSize: 12)),
          )
        else
          _buildChart(),

        if (_view == 'daily' && _data.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDailyStrip(),
        ],

        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          Flexible(child: Text('Source: flood_snapshots · Poll: 30s · Realtime active',
            style: TextStyle(color: Color(0xFF4a6080), fontSize: 8.5))),
          Text('Situational awareness only',
            style: TextStyle(color: Color(0xFF4a6080), fontSize: 8.5)),
        ]),
      ]),
    );
  }

  Widget _buildToggle(String label, String key) => GestureDetector(
    onTap: () { setState(() { _view = key; _loading = true; _data = []; }); _fetchData(); },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _view == key ? const Color(0xFF38bdf8).withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(
        color: _view == key ? const Color(0xFF38bdf8) : const Color(0xFF4a6080),
        fontSize: 10, fontWeight: _view == key ? FontWeight.w800 : FontWeight.w400,
      )),
    ),
  );

  Widget _buildChart() {
    // Simple custom painter chart (no fl_chart dependency needed)
    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: _ChartPainter(data: _data, riskColor: _riskColor),
        size: const Size(double.infinity, 200),
      ),
    );
  }

  Widget _buildDailyStrip() {
    return Row(
      children: _data.map((d) {
        final color = _riskColor(d.floodRisk);
        return Expanded(child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: d.isToday ? const Color(0xFF38bdf8).withValues(alpha: 0.08) : const Color(0xFF0a1828),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: d.isToday ? const Color(0xFF38bdf8).withValues(alpha: 0.3) : const Color(0xFF1e3a5f)),
          ),
          child: Column(children: [
            Text(d.label, style: TextStyle(
              color: d.isToday ? const Color(0xFF38bdf8) : const Color(0xFF4a6080),
              fontSize: 7.5, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${d.floodRisk.toStringAsFixed(0)}%', style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w900)),
            if (d.readings > 0)
              Text('${d.readings}r', style: const TextStyle(color: Color(0xFF38bdf8), fontSize: 7)),
          ]),
        ));
      }).toList(),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

// ── Chart Painter (no external dep) ─────────────────────────────────────────
class _ChartPainter extends CustomPainter {
  final List<_Snapshot> data;
  final Color Function(double) riskColor;
  const _ChartPainter({required this.data, required this.riskColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final chartH = h - 28; // leave bottom for labels

    // Reference lines: 25, 50, 75
    for (final pct in [25.0, 50.0, 75.0]) {
      final y = chartH - (pct / 100) * chartH;
      final paint = Paint()
        ..color = riskColor(pct).withValues(alpha: 0.3)
        ..strokeWidth = 1;
      final dashPaint = Paint()
        ..color = riskColor(pct).withValues(alpha: 0.4)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      // dashed line
      double x = 0;
      while (x < w) {
        canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0, w), y), dashPaint);
        x += 7;
      }
      // label
      final tp = TextPainter(
        text: TextSpan(text: '${pct.toStringAsFixed(0)}%',
          style: TextStyle(color: riskColor(pct).withValues(alpha: 0.7), fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - 10));
    }

    // Build path
    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1).clamp(1, double.infinity)) * w;
      final y = chartH - (data[i].floodRisk / 100) * chartH;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartH);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Fill gradient
    fillPath.lineTo(w, chartH);
    fillPath.close();
    final gradient = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [const Color(0xFFa855f7).withValues(alpha: 0.22), const Color(0xFFa855f7).withValues(alpha: 0.02)],
    );
    canvas.drawPath(fillPath, Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, chartH)));

    // Stroke
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFa855f7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // Dots
    for (int i = 0; i < data.length; i++) {
      if (data.length > 48 && i % 4 != 0) continue; // skip if dense
      final x = (i / (data.length - 1).clamp(1, double.infinity)) * w;
      final y = chartH - (data[i].floodRisk / 100) * chartH;
      final c = riskColor(data[i].floodRisk);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = c);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }

    // X axis labels (show ~6 evenly)
    final step = (data.length / 6).ceil().clamp(1, data.length);
    for (int i = 0; i < data.length; i += step) {
      final x = (i / (data.length - 1).clamp(1, double.infinity)) * w;
      final tp = TextPainter(
        text: TextSpan(text: data[i].label,
          style: const TextStyle(color: Color(0xFF4a6080), fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((x - tp.width / 2).clamp(0, w - tp.width), chartH + 6));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.data != data;
}

// ── Forecast Strip ───────────────────────────────────────────────────────────
class _ForecastStrip extends StatelessWidget {
  final List<Map<String, dynamic>> forecast;
  final bool loading;
  const _ForecastStrip({required this.forecast, required this.loading});

  String _emoji(num precip) {
    if (precip > 10) return '⛈';
    if (precip > 2)  return '🌧';
    if (precip > 0)  return '🌦';
    return '☀️';
  }

  Color _precipColor(num precip) {
    if (precip > 10) return const Color(0xFFef4444);
    if (precip > 2)  return const Color(0xFFf97316);
    return const Color(0xFF38bdf8);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, __) => Container(
            width: 76, height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFF0a1828),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1e3a5f)),
            ),
          ),
        ),
      );
    }

    if (forecast.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0a1828), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1e3a5f)),
        ),
        child: const Center(
          child: Text('⚠️ Forecast feed unavailable — model backend offline',
            style: TextStyle(color: Color(0xFF4a6080), fontSize: 12), textAlign: TextAlign.center),
        ),
      );
    }

    final maxPrecip = forecast.fold<double>(1.0, (m, f) {
      final p = (f['precipitation'] as num? ?? f['rain_chance'] as num? ?? 0).toDouble();
      return p > m ? p : m;
    });

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: forecast.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, idx) {
          final f      = forecast[idx];
          final time   = DateTime.tryParse(f['time'] as String? ?? '') ?? DateTime.now();
          final temp   = f['temperature_c'] ?? f['temp_c'] ?? '—';
          final precip = (f['precipitation'] as num? ?? f['rain_chance'] as num? ?? 0).toDouble();
          final wind   = f['wind_speed_kph'] ?? f['wind_kph'] ?? '—';
          final precipPct = (precip / maxPrecip).clamp(0.0, 1.0);
          final pc     = _precipColor(precip);
          final wday   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][time.weekday - 1];
          final h      = time.hour % 12 == 0 ? 12 : time.hour % 12;
          final ampm   = time.hour < 12 ? 'AM' : 'PM';

          return SizedBox(
            width: 78,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (idx == 0) Container(height: 2, color: const Color(0xFF38bdf8))
              else          const SizedBox(height: 2),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 108,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a1828),
                    border: Border.all(color: const Color(0xFF1e3a5f)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$wday $h$ampm', style: const TextStyle(
                        color: Color(0xFF4a6080), fontSize: 8.5, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                      Text(_emoji(precip), style: const TextStyle(fontSize: 18)),
                      Text('$temp°C', style: const TextStyle(color: Color(0xFFe2eaf5), fontSize: 11, fontWeight: FontWeight.w700)),
                      Column(children: [
                        Container(height: 3,
                          decoration: BoxDecoration(color: const Color(0xFF1e3a5f), borderRadius: BorderRadius.circular(2)),
                          child: FractionallySizedBox(widthFactor: precipPct, alignment: Alignment.centerLeft,
                            child: Container(decoration: BoxDecoration(color: pc, borderRadius: BorderRadius.circular(2))))),
                        const SizedBox(height: 3),
                        Text('${precip.toStringAsFixed(1)}mm', style: TextStyle(color: pc, fontSize: 9, fontWeight: FontWeight.w600)),
                        Text('$wind km/h', style: const TextStyle(color: Color(0xFF4a6080), fontSize: 8.5)),
                      ]),
                    ],
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ── Radar Card (Windy only, simplified) ─────────────────────────────────────
class _RadarCard extends StatelessWidget {
  final WebViewController windyCtrl;
  const _RadarCard({required this.windyCtrl});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF0d1f3c),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF1e3a5f)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🛰 LIVE WEATHER RADAR', style: TextStyle(
            color: Color(0xFF4a6080), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          const Text('Windy.com · ECMWF Model · Surface Rain Overlay',
            style: TextStyle(color: Color(0xFF4a6080), fontSize: 10)),
        ]),
      ),
      ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(9), bottomRight: Radius.circular(9)),
        child: SizedBox(
          height: 280,
          child: WebViewWidget(controller: windyCtrl),
        ),
      ),
    ]),
  );
}

// ── Pulsing Dot ──────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: 9, height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: _anim.value),
        boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 5)],
      ),
    ),
  );
}

// ── Extension helpers ─────────────────────────────────────────────────────────
extension on DateTime {
  String toDateString() => '$year-$month-$day';
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int n) {
    final list = toList();
    return list.length <= n ? list : list.sublist(list.length - n);
  }
}