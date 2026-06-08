import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

// ─── Alert Thresholds ─────────────────────────────────────────────────────────
class _Threshold {
  final double min, max;
  final String label, wl;
  final String action;
  final Color color;
  const _Threshold(this.min, this.max, this.label, this.wl, this.action, this.color);
}

const _thresholds = {
  'NORMAL':   _Threshold(0,   2.4, 'Normal',   '< 2.5m',     'Continue normal activities. Monitor updates.',                    Color(0xFF22c55e)),
  'ADVISORY': _Threshold(2.5, 3.4, 'Advisory', '2.5 – 3.4m', 'Stay alert. Prepare emergency go-bags.',                         Color(0xFFeab308)),
  'WARNING':  _Threshold(3.5, 4.4, 'Warning',  '3.5 – 4.4m', 'Move valuables to higher ground. Be ready to evacuate.',         Color(0xFFf97316)),
  'CRITICAL': _Threshold(4.5, 999, 'Critical', '≥ 4.5m',     'Evacuate immediately to designated evacuation centers.',         Color(0xFFef4444)),
};

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
    return _Prediction(
      probability: (j['probability'] as num?)?.toDouble() ?? 0.0,
      alertLevel:  (j['alert_level']  as num?)?.toInt()   ?? 0,
      status:       j['status']             as String?    ?? '',
      rainfallMm:  (m['rainfall_mm']  as num?)?.toDouble() ?? 0.0,
      windSignal:  (m['wind_signal']   as num?)?.toInt()   ?? 0,
      humidity:    (m['humidity']      as num?)?.toInt()   ?? 0,
      leadTime:     j['lead_time_estimate'] as String?     ?? '6–12 hrs',
    );
  }

  double? get estimatedLevel {
    if (rainfallMm <= 0) return null;
    return double.parse((1.4 + rainfallMm * 0.045).toStringAsFixed(2));
  }

  String get probabilityPct => '${(probability * 100).toStringAsFixed(0)}%';
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
  String _activeTab     = 'radar';
  DateTime _lastUpdated = DateTime.now();
  Timer? _timer;

  late final WebViewController _radarCtrl;
  late final WebViewController _windyCtrl;

  @override
  void initState() {
    super.initState();
    _initWebViews();
    _fetchPrediction();
    _fetchForecast();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchPrediction();
      // FIX: use addPostFrameCallback to avoid setState during layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _lastUpdated = DateTime.now());
      });
    });
  }

  void _initWebViews() {
    _radarCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF091729))
      ..loadHtmlString(_radarHtml);

    _windyCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF091729))
      ..loadRequest(Uri.parse(
          'https://www.windy.com/embed2.html?lat=13.621&lon=123.194&zoom=8&level=surface&overlay=rain&product=ecmwf&message=true&marker=true&location=coordinates'));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _fetchPrediction() async {
    try {
      final res = await http.get(Uri.parse(_modelUrl)).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final p = _Prediction.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        // FIX: guard setState with postFrameCallback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _pred = p; _loading = false; _error = false; });
        });
        widget.onAlertChanged?.call(_alertFromInt(p.alertLevel));
      } else { throw Exception(); }
    } catch (_) {
      if (!mounted) return;
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
          if (mounted) {
            setState(() {
            _forecast        = (body['hourly'] as List? ?? body['forecast'] as List? ?? []).cast();
            _forecastLoading = false;
          });
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
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
    if (_pred == null)  return 'Model offline — no data';
    if (lvl == null)    return 'No active rainfall · Baseline 1.4m';
    if (lvl >= 4.5)     return 'Critical threshold exceeded';
    if (lvl >= 3.5)     return 'Warning threshold exceeded';
    if (lvl >= 2.5)     return 'Advisory range';
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
    final alertInfo  = AlertLevel.levels[_alertFromInt(_pred?.alertLevel ?? 0)]!;
    final lvl        = _pred?.estimatedLevel;
    final hasRain    = (_pred?.rainfallMm ?? 0) > 0;
    final pct        = _pred?.probabilityPct ?? '—';

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

            if (_error) ...[
              _OfflineBanner(),
              const SizedBox(height: 12),
            ],

            _AlertHeader(
              alertInfo:   alertInfo,
              alertColor:  _alertColor,
              pred:        _pred,
              pct:         pct,
              lastUpdated: _lastUpdated,
              formatTime:  _formatTime,
            ),
            const SizedBox(height: 16),

            const _SectionLabel(icon: '📊', text: 'Live Metrics'),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.55,
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

            if (_pred != null) ...[
              const _SectionLabel(icon: '📊', text: 'LSTM Model — Prediction Inputs'),
              const SizedBox(height: 8),
              _PredictionInputTable(pred: _pred!),
              const SizedBox(height: 18),
            ],

            const _SectionLabel(icon: '🖥', text: 'System Status'),
            const SizedBox(height: 8),
            _SystemStatusPanel(
              modelOnline:    !_error && !_loading && _pred != null,
              modelLoading:   _loading,
              modelError:     _error ? 'Model backend offline' : null,
              forecastOnline: !_forecastLoading && _forecast.isNotEmpty,
              forecastLoading: _forecastLoading,
              forecastCount:   _forecast.length,
              formatTime:     _formatTime,
            ),
            const SizedBox(height: 18),

            const _SectionLabel(icon: '⛅', text: '72-Hour Rainfall Forecast'),
            const SizedBox(height: 4),
            const Text('OpenMeteo · Naga City',
              style: TextStyle(color: Color(0xFF4a6080), fontSize: 10)),
            const SizedBox(height: 10),
            _ForecastStrip(forecast: _forecast, loading: _forecastLoading),
            const SizedBox(height: 18),

            const _SectionLabel(icon: '🛰', text: 'Live Weather Radar'),
            const SizedBox(height: 8),
            _RadarCard(
              radarCtrl: _radarCtrl,
              windyCtrl: _windyCtrl,
              activeTab: _activeTab,
              onTabChange: (t) => setState(() => _activeTab = t),
            ),
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
    Text(text.toUpperCase(), style: const TextStyle(
      color: Color(0xFF4a6080), fontSize: 10,
      fontWeight: FontWeight.w800, letterSpacing: 1.5,
    )),
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
      // FIX: left accent strip instead of non-uniform border
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // FIX: left accent strip
      Container(width: 4, color: alertColor),
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [alertColor.withValues(alpha: 0.10), Colors.transparent],
            ),
            border: Border.all(color: alertColor.withValues(alpha: 0.4)),
          ),
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
    ]),
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
          // FIX: top accent strip instead of non-uniform border top
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 28,
            height: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [6, 5, 4, 3, 2, 1, 0].map((v) =>
                Text('${v}m', style: const TextStyle(color: Color(0xFF4a6080), fontSize: 8.5, fontWeight: FontWeight.w600)),
              ).toList(),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 36, height: 180,
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
                height: 180 * pct,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
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
        ]),
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
      ]),
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

    return ClipRRect(
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
      child: GridView.count(
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
                  color: Color(0xFFe2eaf5), fontSize: 9.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(statusLabels[ind.status]!, style: TextStyle(
                  color: c, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(ind.detail, style: const TextStyle(color: Color(0xFF4a6080), fontSize: 8.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Forecast Strip ───────────────────────────────────────────────────────────
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
        height: 110,
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
          color: const Color(0xFF0a1828),
          borderRadius: BorderRadius.circular(8),
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

    // Fixed total height: 2px accent line + 2px spacing + card height
    return SizedBox(
      height: 120, // enough for accent + card
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

          // Build card without Expanded – fixed height
          return SizedBox(
            width: 78,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Accent line for first item only
                if (idx == 0)
                  Container(height: 2, color: const Color(0xFF38bdf8))
                else
                  const SizedBox(height: 2),
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
                        Text('$temp°C', style: const TextStyle(
                          color: Color(0xFFe2eaf5), fontSize: 11, fontWeight: FontWeight.w700)),
                        Column(
                          children: [
                            Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1e3a5f),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                widthFactor: precipPct,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: pc,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text('${precip.toStringAsFixed(1)}mm', style: TextStyle(color: pc, fontSize: 9, fontWeight: FontWeight.w600)),
                            Text('$wind km/h', style: const TextStyle(color: Color(0xFF4a6080), fontSize: 8.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
// ── Radar Card ───────────────────────────────────────────────────────────────
class _RadarCard extends StatelessWidget {
  final WebViewController radarCtrl, windyCtrl;
  final String activeTab;
  final ValueChanged<String> onTabChange;

  const _RadarCard({
    required this.radarCtrl, required this.windyCtrl,
    required this.activeTab, required this.onTabChange,
  });

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
        child: Row(children: [
          const Expanded(child: Text(
            'Windy.com · ECMWF forecast model',
            style: TextStyle(color: Color(0xFF4a6080), fontSize: 10),
          )),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0a1828),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1e3a5f)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _buildTab('🌧 Radar', 'radar'),
              _buildTab('💨 Windy', 'windy'),
            ]),
          ),
        ]),
      ),
      ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(9), bottomRight: Radius.circular(9)),
        child: SizedBox(
          height: 260,
          child: activeTab == 'radar'
            ? WebViewWidget(controller: radarCtrl)
            : WebViewWidget(controller: windyCtrl),
        ),
      ),
    ]),
  );

  Widget _buildTab(String label, String key) => GestureDetector(
    onTap: () => onTabChange(key),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: activeTab == key ? const Color(0xFF38bdf8).withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: activeTab == key ? const Color(0xFF38bdf8) : Colors.transparent),
      ),
      child: Text(label, style: TextStyle(
        color: activeTab == key ? const Color(0xFF38bdf8) : const Color(0xFF4a6080),
        fontSize: 10.5, fontWeight: activeTab == key ? FontWeight.w700 : FontWeight.w400,
      )),
    ),
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

// ─── Radar HTML ───────────────────────────────────────────────────────────────
const _radarHtml = '''
<!DOCTYPE html><html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>html,body,#map{margin:0;padding:0;height:100%;width:100%;background:#091729}</style>
</head>
<body><div id="map"></div>
<script>
  var map=L.map('map',{zoomControl:false,scrollWheelZoom:false}).setView([13.6192,123.1814],10);
  L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    {attribution:'© OpenStreetMap © CARTO',subdomains:'abcd',maxZoom:20}).addTo(map);
  L.marker([13.6192,123.1814]).addTo(map).bindPopup('<b>Monitoring Station</b><br>Triangulo, Naga City');
  fetch('https://api.rainviewer.com/public/weather-maps.json').then(r=>r.json()).then(data=>{
    var past=data.radar.past;
    if(!past||!past.length) return;
    var path=past[past.length-1].path;
    L.tileLayer('https://tilecache.rainviewer.com'+path+'/256/{z}/{x}/{y}/2/1_1.png',
      {opacity:0.5,zIndex:100,attribution:'© RainViewer'}).addTo(map);
  });
</script></body></html>
''';