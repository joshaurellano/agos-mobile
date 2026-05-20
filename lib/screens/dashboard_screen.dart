import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../main.dart';
import '../models/alert_level.dart';
import '../models/notification_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


// ── Model API ─────────────────────────────────────────────────────────────────

const _modelUrl    = 'https://asterisk101-flood-prediction.hf.space/predict_live';
const _forecastUrl = 'https://asterisk101-flood-prediction.hf.space/forecast';

AlertLevelType _alertLevelFromInt(int level) {
  switch (level) {
    case 3:  return AlertLevelType.critical;
    case 2:  return AlertLevelType.warning;
    case 1:  return AlertLevelType.advisory;
    default: return AlertLevelType.normal;
  }
}

class ModelPrediction {
  final double probability;
  final int    alertLevel;
  final String status;
  final double rainfallMm;
  final int    windSignal;
  final int    humidity;
  final String leadTime;

  const ModelPrediction({
    required this.probability,
    required this.alertLevel,
    required this.status,
    required this.rainfallMm,
    required this.windSignal,
    required this.humidity,
    required this.leadTime,
  });

  factory ModelPrediction.fromJson(Map<String, dynamic> j) {
    final m = j['live_metrics'] as Map<String, dynamic>? ?? {};
    return ModelPrediction(
      probability: (j['probability'] as num?)?.toDouble() ?? 0.0,
      alertLevel:  (j['alert_level'] as num?)?.toInt()    ?? 0,
      status:      j['status']              as String?    ?? '',
      rainfallMm:  (m['rainfall_mm'] as num?)?.toDouble() ?? 0.0,
      windSignal:  (m['wind_signal']  as num?)?.toInt()   ?? 0,
      humidity:    (m['humidity']     as num?)?.toInt()   ?? 0,
      leadTime:    j['lead_time_estimate']  as String?    ?? '—',
    );
  }
}

// ── Dashboard screen ──────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final ValueChanged<AlertLevelType>? onAlertChanged;
  final bool residentView;

  const DashboardScreen({
    super.key,
    this.onAlertChanged,
    this.residentView = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ModelPrediction? _prediction;
  bool _modelLoading = true;
  bool _modelError   = false;

  List<Map<String, dynamic>> _forecast = [];
  bool _forecastLoading = true;

  String _activeTab = 'radar';
  Timer? _pollTimer;

  WebViewController? _radarController;
  WebViewController? _windyController;

  // ── Derived values ────────────────────────────────────────────
  static const double _baseline = 1.4;
  static const double _riseRate = 0.045;

  double? get _estimatedLevel {
    if (_prediction == null || _prediction!.rainfallMm <= 0) return null;
    return double.parse(
        (_baseline + _prediction!.rainfallMm * _riseRate).toStringAsFixed(2));
  }

  AlertLevelType get _currentAlertType =>
      _alertLevelFromInt(_prediction?.alertLevel ?? 0);

  Color get _waterLevelColor {
    final lvl = _estimatedLevel;
    if (lvl == null)  return AppColors.textMuted;
    if (lvl >= 4.5)   return AppColors.red;
    if (lvl >= 3.5)   return AppColors.orange;
    if (lvl >= 2.5)   return AppColors.accent;
    return AppColors.green;
  }

  String get _waterLevelSub {
    final lvl = _estimatedLevel;
    if (lvl == null && _prediction == null) return 'No data available';
    if (lvl == null) return 'Est. · No active rainfall · Baseline level';
    if (lvl >= 4.5)  return 'Est. · Critical threshold exceeded';
    if (lvl >= 3.5)  return 'Est. · Warning threshold exceeded';
    if (lvl >= 2.5)  return 'Est. · Advisory range';
    return 'Est. · Within safe range';
  }

  Color get _windColor {
    final sig = _prediction?.windSignal ?? 0;
    if (sig >= 3) return AppColors.red;
    if (sig == 2) return AppColors.orange;
    if (sig == 1) return AppColors.accent;
    return AppColors.green;
  }

  String get _windSub {
    final sig = _prediction?.windSignal ?? 0;
    if (sig >= 4) return 'Extremely destructive · >185 km/h';
    if (sig == 3) return 'Destructive · >121 km/h';
    if (sig == 2) return 'Damaging · >61 km/h';
    if (sig == 1) return 'Strong · >30 km/h';
    return 'No active signal';
  }

  Color get _probabilityColor {
    final lvl = _prediction?.alertLevel ?? 0;
    if (lvl >= 2) return AppColors.red;
    if (lvl == 1) return AppColors.orange;
    return AppColors.green;
  }

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initWebViews();
    _fetchPrediction();
    _fetchForecast();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _fetchPrediction());
  }

  void _initWebViews() {
    _radarController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.blueDark)
      ..loadHtmlString(_radarHtml);

    _windyController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.blueDark)
      ..loadRequest(Uri.parse(
          'https://www.windy.com/embed2.html?lat=13.621&lon=123.194&zoom=8&level=surface&overlay=rain&product=ecmwf&message=true&marker=true&location=coordinates'));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPrediction() async {
    try {
      final res = await http
          .get(Uri.parse(_modelUrl))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final p = ModelPrediction.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        setState(() {
          _prediction   = p;
          _modelLoading = false;
          _modelError   = false;
        });
        widget.onAlertChanged?.call(_alertLevelFromInt(p.alertLevel));
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _modelLoading = false;
        _modelError   = true;
      });
    }
  }

  Future<void> _fetchForecast() async {
    try {
      final res = await http
          .get(Uri.parse(_forecastUrl))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['forecast'] as List<dynamic>? ?? [];
        setState(() {
          _forecast        = list.cast<Map<String, dynamic>>();
          _forecastLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _forecastLoading = false);
    }
  }

  // ── Evacuation dialog ─────────────────────────────────────────

  void _showEvacuationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.blueDark,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('⚠️ Send Evacuation Alert?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will send an evacuation alert to all registered officials and residents in Barangay Triangulo.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blueMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📢 Alert Message:',
                      style: TextStyle(
                          color: AppColors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  SizedBox(height: 6),
                  Text(
                    '"Flooding possible in the next 6 hours. Please proceed to designated evacuation centers immediately."',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              const message = 'One-Click Evacuation Alert dispatched to all officials and residents.';

              // Broadcast locally (in-app)
              AlertBus.send(NotificationLog(
                id: DateTime.now().millisecondsSinceEpoch,
                time: TimeOfDay.now().format(context),
                type: NotificationType.critical,
                message: message,
                sentBy: 'Admin (Manual)',
                read: false,
              ));

              // Send to Supabase → React web and other Flutter clients get it via Realtime
              final error = await Supabase.instance.client.from('alerts').insert({
                'type':    'CRITICAL',
                'message': message,
                'sent_by': 'Admin (Manual)',
              }).then((_) => null).catchError((e) => e.toString());

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(error == null ? '✅ Evacuation alert sent!' : '⚠️ Local only: $error'),
                backgroundColor: error == null ? AppColors.green : AppColors.orange,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('🚨 Send Alert Now'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final alertInfo = AlertLevel.levels[_currentAlertType]!;
    final lvl       = _estimatedLevel;
    final pct = _prediction != null
        ? '${(_prediction!.probability * 100).toStringAsFixed(0)}%'
        : '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Model error banner ───────────────────────────────
          if (_modelError)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.red.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Text('⚠️ '),
                Expanded(
                  child: Text(
                    'Model backend offline — showing simulated data. Start app.py to enable live predictions.',
                    style: const TextStyle(
                        color: AppColors.red, fontSize: 12),
                  ),
                ),
              ]),
            ),

          // ── Alert Banner ─────────────────────────────────────
          _AccentBanner(
            color: alertInfo.color,
            margin: const EdgeInsets.only(bottom: 16),
            child: LayoutBuilder(builder: (_, c) {
              final narrow = c.maxWidth < 400;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: alertInfo.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${alertInfo.label.toUpperCase()} LEVEL',
                          style: TextStyle(
                            color: alertInfo.color,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (_prediction != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: alertInfo.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: alertInfo.color.withOpacity(0.4)),
                          ),
                          child: Text(
                            'AI: $pct flood risk',
                            style: TextStyle(
                              color: alertInfo.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(alertInfo.description,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('🔔 ${alertInfo.action}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: alertInfo.color.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _prediction != null
                              ? 'Model Status'
                              : 'Status Message',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _prediction != null
                              ? _prediction!.status
                              : '⚠️ Flooding possible in the next 6 hrs',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (_prediction != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '⏱ Lead time: ${_prediction!.leadTime}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),

          // ── KPI Grid ─────────────────────────────────────────
          LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              childAspectRatio: cols == 4 ? 1.5 : 1.4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _StatCard(
                  icon: '💧',
                  label: 'Est. Water Level',
                  value: lvl != null ? '${lvl}m' : 'N/A',
                  sub: _waterLevelSub,
                  color: _waterLevelColor,
                  dim: lvl == null,
                ),
                _StatCard(
                  icon: '🌧',
                  label: 'Rainfall (Current)',
                  value: _prediction != null
                      ? '${_prediction!.rainfallMm.toStringAsFixed(1)}mm'
                      : '45.1mm',
                  sub: _prediction != null
                      ? 'WeatherAPI · Live'
                      : 'PAGASA Station',
                  color: AppColors.accent,
                ),
                _StatCard(
                  icon: '🌀',
                  label: 'Wind Signal',
                  value: _prediction != null
                      ? '#${_prediction!.windSignal}'
                      : '—',
                  sub: _windSub,
                  color: _windColor,
                ),
                _StatCard(
                  icon: '🤖',
                  label: 'Flood Probability',
                  value: _modelLoading ? '...' : pct,
                  sub: _prediction != null
                      ? '${_prediction!.humidity}% humidity'
                      : 'LSTM Model',
                  color: _probabilityColor,
                ),
              ],
            );
          }),
          const SizedBox(height: 16),

          // ── Water Level Gauge ─────────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                    child: Text(
                      '💧 Estimated Water Level Gauge',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      lvl != null
                          ? 'Derived from rainfall'
                          : 'No live feed',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // Legend
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _LegendItem(color: AppColors.orange, label: 'Warning (3.5m)'),
                    _LegendItem(color: AppColors.red, label: 'Critical (4.5m)'),
                  ],
                ),
                const SizedBox(height: 12),
                // Gauge
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    color: AppColors.blueMid,
                    child: lvl != null
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              // Water fill
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 200 *
                                    (lvl / 6.0).clamp(0.0, 1.0),
                                child: Container(
                                  color: lvl >= 4.5
                                      ? AppColors.red.withOpacity(0.15)
                                      : lvl >= 3.5
                                          ? AppColors.orange
                                              .withOpacity(0.15)
                                          : lvl >= 2.5
                                              ? AppColors.accent
                                                  .withOpacity(0.15)
                                              : AppColors.green
                                                  .withOpacity(0.10),
                                ),
                              ),
                              // Warning line 3.5m
                              Positioned(
                                bottom: 200 * (3.5 / 6.0),
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 1,
                                  color: AppColors.orange.withOpacity(0.6),
                                ),
                              ),
                              // Critical line 4.5m
                              Positioned(
                                bottom: 200 * (4.5 / 6.0),
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 1,
                                  color: AppColors.red.withOpacity(0.6),
                                ),
                              ),
                              // Value
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    child: Text(
                                      '${lvl}m',
                                      style: TextStyle(
                                        color: _waterLevelColor,
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'Baseline 1.4m + rainfall factor (×0.045)',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('📡',
                                  style: TextStyle(fontSize: 32,
                                      color: AppColors.textMuted)),
                              SizedBox(height: 8),
                              Text('No sensor data available',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                'Start the model backend to see estimated water level',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Live Weather Radar ────────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                    child: Text(
                      '🛰 Live Weather Radar — Naga City',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TabButton(
                    label: '🌧 Radar',
                    active: _activeTab == 'radar',
                    onTap: () => setState(() => _activeTab = 'radar'),
                  ),
                  const SizedBox(width: 6),
                  _TabButton(
                    label: '💨 Windy',
                    active: _activeTab == 'windy',
                    onTap: () => setState(() => _activeTab = 'windy'),
                  ),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 300,
                    child: _activeTab == 'radar'
                        ? WebViewWidget(controller: _radarController!)
                        : WebViewWidget(controller: _windyController!),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _activeTab == 'radar'
                      ? '● RainViewer radar overlay · © OpenStreetMap / CARTO'
                      : 'Powered by Windy.com · ECMWF forecast model',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Weather Forecast ──────────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⛅ Weather Forecast Strip — Next 72 Hours',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                if (_forecastLoading)
                  const Text('Loading forecast...',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 13))
                else if (_forecast.isEmpty)
                  const Text(
                    '⚠️ Forecast unavailable — backend offline',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _forecast.map((f) {
                        final time = DateTime.tryParse(
                                f['time'] as String? ?? '') ??
                            DateTime.now();
                        final label =
                            '${_weekday(time.weekday)} ${_hour(time)}';
                        return Container(
                          width: 76,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.blueMid,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.blueBorder),
                          ),
                          child: Column(children: [
                            Text(
                              label,
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            if (f['icon_url'] != null)
                              Image.network(
                                f['icon_url'] as String,
                                width: 28,
                                height: 28,
                                errorBuilder: (_, __, ___) =>
                                    const Text('🌧',
                                        style: TextStyle(fontSize: 22)),
                              )
                            else
                              const Text('🌧',
                                  style: TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(
                              '${f['temp_c']}°C',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${f['rain_chance']}% 🌧',
                              style: const TextStyle(
                                  color: AppColors.accent, fontSize: 10),
                            ),
                            Text(
                              '${f['wind_kph']} km/h',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 9),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Alert Levels Reference ────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🚦 Flood Risk Alert Levels',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ...AlertLevel.levels.entries.map((entry) {
                  final isCurrent = entry.key == _currentAlertType;
                  final info      = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? info.color.withOpacity(0.1)
                          : AppColors.blueMid,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent
                            ? info.color.withOpacity(0.5)
                            : AppColors.blueBorder,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: info.color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              info.label.toUpperCase(),
                              style: TextStyle(
                                color: info.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              info.description.split('.').first,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: info.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'CURRENT',
                            style: TextStyle(
                              color: info.color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ]),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Evacuation Button ─────────────────────────────────
          if (!widget.residentView)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.red.withOpacity(0.2)),
              ),
              child: Column(children: [
                const Text(
                  'EMERGENCY ACTION',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _showEvacuationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      '🚨  Send One-Click Evacuation Alert',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Notifies all registered officials and residents in Barangay Triangulo',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Radar HTML ────────────────────────────────────────────────────────────────

const _radarHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    html, body, #map { margin:0; padding:0; height:100%; width:100%; background:#0d1f3c; }
  </style>
</head>
<body>
<div id="map"></div>
<script>
  var map = L.map('map',{zoomControl:false,scrollWheelZoom:false})
             .setView([13.6192,123.1814],10);
  L.tileLayer(
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    {attribution:'© OpenStreetMap © CARTO',subdomains:'abcd',maxZoom:20}
  ).addTo(map);
  L.marker([13.6192,123.1814]).addTo(map)
   .bindPopup('<b>Monitoring Station</b><br>Triangulo, Naga City');
  fetch('https://api.rainviewer.com/public/weather-maps.json')
    .then(r=>r.json())
    .then(data=>{
      var past=data.radar.past;
      if(!past||!past.length) return;
      var path=past[past.length-1].path;
      L.tileLayer(
        'https://tilecache.rainviewer.com'+path+'/256/{z}/{x}/{y}/2/1_1.png',
        {opacity:0.5,zIndex:100,attribution:'© RainViewer'}
      ).addTo(map);
    });
</script>
</body>
</html>
''';

// ── Shared widgets ────────────────────────────────────────────────────────────

class _AccentBanner extends StatelessWidget {
  final Color  color;
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const _AccentBanner({
    required this.color,
    required this.child,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              border: Border.all(color: color.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(width: 4, color: color),
          ),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blueCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blueBorder),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon, label, value, sub;
  final Color  color;
  final bool   dim;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blueCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.blueBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Flexible(
              child: Text(
                sub,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 9),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withOpacity(0.15)
              : AppColors.blueMid,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? AppColors.accent : AppColors.blueBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.accent : AppColors.textMuted,
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 16,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]);
  }
}

String _weekday(int d) =>
    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];

String _hour(DateTime dt) {
  final h      = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final suffix = dt.hour < 12 ? 'AM' : 'PM';
  return '$h $suffix';
}