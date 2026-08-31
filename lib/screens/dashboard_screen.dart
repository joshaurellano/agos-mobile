// dashboard_screen.dart
//
// Resident-facing home screen for AGOS. Redesigned to read like a friendly
// weather app first and a technical instrument panel second: a plain-language
// safety headline up top, a single "what to do right now" card, one-tap
// shortcuts to the other tabs, and the fuller live data (map, forecast,
// radar) further down for anyone who wants to dig in.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/alert_level.dart';
import '../services/auth_service.dart';
import '../theme/panahon_ui.dart';

// ─── URLs ─────────────────────────────────────────────────────────────────────
// Read from .env (see README) so the backend can be swapped between
// dev/staging/prod without touching code. Falls back to the current
// production Cloud Run service if the keys are missing, so the app still
// runs for anyone who hasn't updated their .env yet.
const _fallbackBaseUrl = 'https://flood-api-553657561163.asia-southeast1.run.app';

String get _modelUrl =>
    dotenv.env['MODEL_API_URL'] ?? '$_fallbackBaseUrl/api/predict-flood';

String get _forecastUrl =>
    dotenv.env['FORECAST_API_URL'] ?? '$_fallbackBaseUrl/api/forecast';

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

// ─── Plain-language guidance per alert level ──────────────────────────────────
// Shared by the "Right Now" card (current level only) and the full reference
// table further down the page (all four levels).
class _LevelGuidance {
  final String key, range;
  final List<String> actions;
  const _LevelGuidance(this.key, this.range, this.actions);
}

const _levelGuidance = [
  _LevelGuidance('NORMAL', '< 2.5m', [
    'Continue your normal activities.',
    'Check the app occasionally for updates.',
  ]),
  _LevelGuidance('ADVISORY', '2.5 – 3.4m', [
    'Stay alert and monitor rainfall updates.',
    'Prepare an emergency go-bag.',
    'Move vehicles and valuables away from low-lying areas.',
  ]),
  _LevelGuidance('WARNING', '3.5 – 4.4m', [
    'Move valuables and appliances to higher ground.',
    'Charge phones and power banks.',
    'Keep go-bags ready near the door.',
    'Avoid flooded roads and bridges.',
  ]),
  _LevelGuidance('CRITICAL', '≥ 4.5m', [
    'Evacuate immediately to the nearest designated center.',
    'Turn off electrical mains before leaving, if safe.',
    'Assist elderly, children, and PWDs first.',
    'Follow official evacuation routes only.',
  ]),
];

// ─── Friendly hero copy per alert level ───────────────────────────────────────
class _HeroCopy {
  final String headline, tagline;
  const _HeroCopy(this.headline, this.tagline);
}

const _heroCopy = {
  'NORMAL':   _HeroCopy("You're Safe Right Now",  'No flooding risk in Brgy. Triangulo. Enjoy your day.'),
  'ADVISORY': _HeroCopy('Stay Alert',              'Water levels are starting to rise. Keep an eye on updates.'),
  'WARNING':  _HeroCopy('Get Ready to Evacuate',   'Flooding is likely soon. Prepare to leave if it worsens.'),
  'CRITICAL': _HeroCopy('Evacuate Now',            'Flooding is happening or about to happen. Move to safety.'),
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
      leadTime:     j['lead_time_estimate']?.toString()    ?? '1–3 hrs',
    );
  }

  double? get estimatedLevel {
    if (rainfallMm <= 0) return null;
    return double.parse((1.4 + rainfallMm * 0.045).toStringAsFixed(2));
  }

  String get probabilityPct => '${(probability * 100).toStringAsFixed(0)}%';

  String get riskWord {
    if (probability >= 0.75) return 'Severe';
    if (probability >= 0.50) return 'High';
    if (probability >= 0.25) return 'Moderate';
    return 'Low';
  }
}

// ─── Snapshot for chart ───────────────────────────────────────────────────────
class _Snapshot {
  final String label;
  final double floodRisk;
  final bool isToday;
  final int readings;
  const _Snapshot({required this.label, required this.floodRisk, this.isToday = false, this.readings = 0});
}

// ─── AlertLevelType extension ─────────────────────────────────────────────────
extension AlertLevelTypeX on AlertLevelType {
  AlertLevel get info => AlertLevel.levels[this]!;
  Color get color => info.color;
  String get label => info.label;

  IconData get icon {
    switch (this) {
      case AlertLevelType.normal:   return Icons.check_circle_outline_rounded;
      case AlertLevelType.advisory: return Icons.info_outline_rounded;
      case AlertLevelType.warning:  return Icons.warning_amber_rounded;
      case AlertLevelType.critical: return Icons.crisis_alert_rounded;
    }
  }

  bool get shouldPulse =>
      this == AlertLevelType.critical || this == AlertLevelType.warning;
}

// ─── Relative time helper ("just now", "5m ago") ──────────────────────────────
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _greetingWord() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

// ─── Main Widget ──────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final ValueChanged<AlertLevelType>? onAlertChanged;
  // Lets the "Quick Actions" row jump straight to another bottom-nav tab
  // (0=Dashboard, 1=Map, 2=Rainfall, 3=Evacuation) — same pattern the
  // notification bell in MainShell already uses.
  final ValueChanged<int>? onNavigate;
  // Opens the Alerts screen (now a pushed page rather than a bottom-nav tab).
  final VoidCallback? onOpenAlerts;
  const DashboardScreen({super.key, this.onAlertChanged, this.onNavigate, this.onOpenAlerts});

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

  @override
  void initState() {
    super.initState();
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
    final hasRain   = (_pred?.rainfallMm ?? 0) > 0;
    final user = context.watch<AuthService>().currentUser;
    final firstName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim().split(' ').first
        : 'Neighbor';

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
            if (_error) ...[_OfflineBanner(), const SizedBox(height: 12)],

            _GreetingRow(firstName: firstName),
            const SizedBox(height: 10),

            _SafetyHeroCard(
              alertKey: _currentAlertKey,
              alertColor: _alertColor,
              pred: _pred,
              lastUpdated: _lastUpdated,
              onEvacuate: () => widget.onNavigate?.call(3),
            ),
            const SizedBox(height: 16),

            _RightNowCard(alertKey: _currentAlertKey, alertColor: _alertColor),
            const SizedBox(height: 16),

            _QuickActionsRow(onNavigate: widget.onNavigate, onOpenAlerts: widget.onOpenAlerts),
            const SizedBox(height: 20),

            const _SectionLabel(icon: '⛅', text: "Today's Conditions"),
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
                  icon: '🌧', label: 'Rainfall Right Now',
                  value: _pred != null ? _pred!.rainfallMm.toStringAsFixed(1) : '—',
                  unit: 'mm/hr',
                  sub: hasRain ? 'Actively raining in your area' : 'No rain detected right now',
                  color: const Color(0xFF38bdf8),
                  badge: _pred != null
                      ? (_pred!.rainfallMm > 10 ? '🔴 Heavy'
                        : _pred!.rainfallMm > 2 ? '🟡 Moderate'
                        : '🟢 Light')
                      : null,
                ),
                _MetricCard(
                  icon: '🤖', label: 'Chance of Flooding',
                  value: _pred != null ? _pred!.riskWord : '—',
                  sub: _pred != null ? 'AI estimate · ${_pred!.probabilityPct}' : 'Forecast unavailable',
                  color: _probabilityColor,
                  dim: _pred == null,
                ),
              ],
            ),
            const SizedBox(height: 18),

            _FloodForecastChart(),
            const SizedBox(height: 18),

            const _SectionLabel(icon: '📋', text: 'Alert Levels Explained'),
            const SizedBox(height: 8),
            _AlertLevelTable(currentAlertKey: _currentAlertKey),
            const SizedBox(height: 18),

            const _SectionLabel(icon: '🌦', text: '3-Day Rain Outlook'),
            const SizedBox(height: 4),
            const Text('OpenMeteo · Naga City',
                style: TextStyle(color: Color(0xFF4a6080), fontSize: 10)),
            const SizedBox(height: 10),
            _ForecastStrip(forecast: _forecast, loading: _forecastLoading),
            const SizedBox(height: 8),

            _MapTeaserCard(onTap: () => widget.onNavigate?.call(1)),
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
                "We're having trouble reaching live data. Showing the last known status.",
                style: TextStyle(color: Color(0xFFf87171), fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
      ),
    ]),
  );
}

// ── Greeting ───────────────────────────────────────────────────────────────
class _GreetingRow extends StatelessWidget {
  final String firstName;
  const _GreetingRow({required this.firstName});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${_greetingWord()}, $firstName 👋', style: const TextStyle(
        color: AppColors.textPri, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2,
      )),
      const SizedBox(height: 2),
      const Text("Here's today's flood outlook for Brgy. Triangulo.",
          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ],
  );
}

// ── Safety Hero Card ─────────────────────────────────────────────────────────
class _SafetyHeroCard extends StatelessWidget {
  final String alertKey;
  final Color alertColor;
  final _Prediction? pred;
  final DateTime lastUpdated;
  final VoidCallback onEvacuate;

  const _SafetyHeroCard({
    required this.alertKey, required this.alertColor, required this.pred,
    required this.lastUpdated, required this.onEvacuate,
  });

  @override
  Widget build(BuildContext context) {
    final copy = _heroCopy[alertKey] ?? _heroCopy['NORMAL']!;
    final alertType = _alertFromInt(_alertKeyToInt(alertKey));
    final severe = alertKey == 'WARNING' || alertKey == 'CRITICAL';

    return PanahonHeroCard(
      accentColor: alertColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.location_on_rounded, color: AppColors.textMuted, size: 13),
            const SizedBox(width: 3),
            const Expanded(
              child: Text('Brgy. Triangulo, Naga City',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            _PulsingDot(color: alertColor),
            const SizedBox(width: 5),
            Text('Updated ${_relativeTime(lastUpdated)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('FLOOD PROBABILITY', style: TextStyle(
                    color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    pred != null ? (pred!.probability * 100).toStringAsFixed(0) : '—',
                    style: TextStyle(color: alertColor, fontSize: 46,
                        fontWeight: FontWeight.w900, height: 1, letterSpacing: -1.4),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 3),
                    child: Text('%', style: TextStyle(
                        color: alertColor, fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(copy.headline, style: const TextStyle(
                    color: AppColors.textPri, fontSize: 16, fontWeight: FontWeight.w800,
                    height: 1.15, letterSpacing: -0.2)),
                const SizedBox(height: 3),
                Text(copy.tagline, style: const TextStyle(
                    color: AppColors.textSec, fontSize: 12, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: alertColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Icon(alertType.icon, color: alertColor, size: 24),
              ),
              const SizedBox(height: 8),
              const Text('WATER CODE', style: TextStyle(
                  color: AppColors.textMuted, fontSize: 7.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: alertColor.withValues(alpha: 0.5)),
                ),
                child: Text(alertKey, style: TextStyle(
                    color: alertColor, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
              ),
            ]),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _StatChip(
              icon: Icons.water_drop_rounded,
              text: pred?.estimatedLevel != null
                  ? '${pred!.estimatedLevel!.toStringAsFixed(1)}m water level'
                  : 'Baseline 1.4m water level',
              color: alertColor,
            ),
            if (pred != null)
              _StatChip(
                icon: Icons.schedule_rounded,
                text: 'Next check ~${pred!.leadTime}',
                color: AppColors.accent,
              ),
          ]),
          if (severe) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onEvacuate,
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('View Evacuation Routes',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: alertColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  static int _alertKeyToInt(String key) {
    switch (key) {
      case 'CRITICAL': return 3;
      case 'WARNING':  return 2;
      case 'ADVISORY': return 1;
      default:         return 0;
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StatChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.bgDeep.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(
          color: AppColors.textSec, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── "Right Now, You Should" Card ─────────────────────────────────────────────
class _RightNowCard extends StatelessWidget {
  final String alertKey;
  final Color alertColor;
  const _RightNowCard({required this.alertKey, required this.alertColor});

  @override
  Widget build(BuildContext context) {
    final guidance = _levelGuidance.firstWhere(
      (g) => g.key == alertKey,
      orElse: () => _levelGuidance.first,
    );
    final isNormal = alertKey == 'NORMAL';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alertColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isNormal ? Icons.check_circle_rounded : Icons.checklist_rounded,
              color: alertColor, size: 16),
          const SizedBox(width: 6),
          Text(isNormal ? 'Nothing to do right now' : 'Right now, you should:', style: TextStyle(
              color: alertColor, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        ...guidance.actions.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.circle, size: 5, color: alertColor.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Expanded(child: Text(a, style: const TextStyle(
                color: AppColors.textPri, fontSize: 12.5, height: 1.4))),
          ]),
        )),
      ]),
    );
  }
}

// ── Quick Actions Row ─────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  final ValueChanged<int>? onNavigate;
  final VoidCallback? onOpenAlerts;
  const _QuickActionsRow({required this.onNavigate, this.onOpenAlerts});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (icon: Icons.radar_rounded,         label: 'Flood\nMap',          tab: 1),
      (icon: Icons.water_drop_rounded,    label: 'Rainfall\nDetails',   tab: 2),
      (icon: Icons.directions_run_rounded,label: 'Evacuation\nCenters', tab: 3),
      (icon: Icons.notifications_rounded, label: 'Alerts &\nAdvisories', tab: -1),
    ];

    return Row(
      children: actions.map((a) {
        final isLast = a == actions.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: GestureDetector(
              onTap: () => a.tab == -1 ? onOpenAlerts?.call() : onNavigate?.call(a.tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgBorder),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(a.icon, color: AppColors.accent, size: 17),
                  ),
                  const SizedBox(height: 7),
                  Text(a.label, textAlign: TextAlign.center, style: const TextStyle(
                      color: AppColors.textSec, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.2)),
                ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
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
                  color: Color(0xFF4a6080), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
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
                Text(sub, style: const TextStyle(color: Color(0xFF8da4be), fontSize: 9),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ]),
          ),
        ),
      ]),
    ),
  );
}

// ── Map Teaser Link ────────────────────────────────────────────────────────────
// Slim link row pointing to the dedicated Flood Map tab, echoing the small
// "Rain Map" link PANaHON tucks under its Location Forecast screen — the
// full interactive map + live radar now live on their own page.
class _MapTeaserCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MapTeaserCard({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1f3c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1e3a5f)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.radar_rounded, color: AppColors.accent, size: 17),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Flood Zone Map & Live Radar', style: TextStyle(
                color: AppColors.textPri, fontSize: 12.5, fontWeight: FontWeight.w700)),
            SizedBox(height: 1),
            Text('See the barangay boundary and rain moving in, live',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
      ]),
    ),
  );
}

// ── Alert Level Reference Table ───────────────────────────────────────────────
class _AlertLevelTable extends StatelessWidget {
  final String currentAlertKey;
  const _AlertLevelTable({required this.currentAlertKey});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0d1f3c),
          border: Border.all(color: const Color(0xFF1e3a5f)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: _levelGuidance.asMap().entries.map((e) {
            final idx   = e.key;
            final item  = e.value;
            final isCur = item.key == currentAlertKey;
            final color = _thresholds[item.key]!.color;
            final isLast = idx == _levelGuidance.length - 1;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCur ? color.withValues(alpha: 0.08) : Colors.transparent,
                border: Border(
                  bottom: isLast ? BorderSide.none : const BorderSide(color: Color(0xFF1e3a5f))),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
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
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ...item.actions.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('•  ', style: TextStyle(
                            color: isCur ? color : const Color(0xFF2a4060),
                            fontSize: 10.5, height: 1.4,
                          )),
                          Expanded(child: Text(a, style: TextStyle(
                            color: isCur ? const Color(0xFFe2eaf5) : const Color(0xFF4a6080),
                            fontSize: 10.5, height: 1.4,
                          ))),
                        ]),
                      )),
                    ]),
                  ),
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

// ── LSTM Flood Probability Trend Chart ───────────────────────────────────────
class _FloodForecastChart extends StatefulWidget {
  const _FloodForecastChart();
  @override
  State<_FloodForecastChart> createState() => _FloodForecastChartState();
}

class _FloodForecastChartState extends State<_FloodForecastChart> {
  String _view = 'hourly';
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
        final since = DateTime.now().subtract(const Duration(days: 14));
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
          _data = days.takeLast(14).map((d) {
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

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
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
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionLabel(icon: '📈', text: _view == 'daily' ? '14-Day Flood Forecast' : '24-Hour Flood Risk Trend'),
            const SizedBox(height: 2),
            Text(
              'How the risk has been changing'
              '${_lastFetched != null ? ' · synced ${_formatTime(_lastFetched!)}' : ''}',
              style: const TextStyle(color: Color(0xFF4a6080), fontSize: 9),
            ),
          ])),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0a1828),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1e3a5f)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _buildToggle('24-Hour', 'hourly'),
              _buildToggle('14-Day', 'daily'),
            ]),
          ),
        ]),
        const SizedBox(height: 12),

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
                const Text('Current Flood Risk', style: TextStyle(
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

        if (_loading)
          Container(
            height: 200, alignment: Alignment.center,
            child: const Text('Loading the latest readings...',
                style: TextStyle(color: Color(0xFF4a6080), fontSize: 12)),
          )
        else if (_data.isEmpty)
          Container(
            height: 200, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0a1828),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1e3a5f)),
            ),
            child: const Text('⚠️ No readings yet',
                style: TextStyle(color: Color(0xFF4a6080), fontSize: 12)),
          )
        else
          _buildChart(),

        if (_view == 'daily' && _data.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildForecastList(),
        ],
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

  Widget _buildChart() => SizedBox(
    height: 200,
    child: CustomPaint(
      painter: _ChartPainter(data: _data, riskColor: _riskColor),
      size: const Size(double.infinity, 200),
    ),
  );

  // Row-per-day list, styled after PANaHON's "5-Day Forecast" list: an icon,
  // the day label, a plain-language risk description, and a value pill —
  // just extended out to 14 days of flood risk instead of temperature.
  String _riskWord(double pct) {
    if (pct >= 75) return 'Severe flood risk';
    if (pct >= 50) return 'High flood risk';
    if (pct >= 25) return 'Moderate flood risk';
    return 'Low flood risk';
  }

  String _riskEmoji(double pct) {
    if (pct >= 75) return '⛈';
    if (pct >= 50) return '🌧';
    if (pct >= 25) return '🌦';
    return '🌤';
  }

  Widget _buildForecastList() => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0a1828),
        border: Border.all(color: const Color(0xFF1e3a5f)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: _data.asMap().entries.map((e) {
          final idx    = e.key;
          final d      = e.value;
          final isLast = idx == _data.length - 1;
          final color  = _riskColor(d.floodRisk);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: d.isToday ? const Color(0xFF38bdf8).withValues(alpha: 0.06) : Colors.transparent,
              border: Border(
                bottom: isLast ? BorderSide.none : const BorderSide(color: Color(0xFF13284a)),
              ),
            ),
            child: Row(children: [
              SizedBox(
                width: 58,
                child: Text(d.label, style: TextStyle(
                  color: d.isToday ? const Color(0xFF38bdf8) : const Color(0xFFe2eaf5),
                  fontSize: 11, fontWeight: FontWeight.w800,
                )),
              ),
              Text(_riskEmoji(d.floodRisk), style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_riskWord(d.floodRisk), style: const TextStyle(
                    color: Color(0xFF8da4be), fontSize: 11.5)),
              ),
              if (d.readings > 0) ...[
                Text('${d.readings} readings', style: const TextStyle(
                    color: Color(0xFF4a6080), fontSize: 9)),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text('${d.floodRisk.toStringAsFixed(0)}%',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ]),
          );
        }).toList(),
      ),
    ),
  );
}

// ── Chart Painter ─────────────────────────────────────────────────────────────
class _ChartPainter extends CustomPainter {
  final List<_Snapshot> data;
  final Color Function(double) riskColor;
  const _ChartPainter({required this.data, required this.riskColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final chartH = h - 28;

    for (final pct in [25.0, 50.0, 75.0]) {
      final y = chartH - (pct / 100) * chartH;
      final dashPaint = Paint()
        ..color = riskColor(pct).withValues(alpha: 0.4)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      double x = 0;
      while (x < w) {
        canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0, w), y), dashPaint);
        x += 7;
      }
      final tp = TextPainter(
        text: TextSpan(text: '${pct.toStringAsFixed(0)}%',
            style: TextStyle(color: riskColor(pct).withValues(alpha: 0.7), fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - 10));
    }

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
    fillPath.lineTo(w, chartH);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFa855f7).withValues(alpha: 0.22),
        const Color(0xFFa855f7).withValues(alpha: 0.02),
      ],
    );
    canvas.drawPath(fillPath,
        Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, chartH)));
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFa855f7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    for (int i = 0; i < data.length; i++) {
      if (data.length > 48 && i % 4 != 0) continue;
      final x = (i / (data.length - 1).clamp(1, double.infinity)) * w;
      final y = chartH - (data[i].floodRisk / 100) * chartH;
      final c = riskColor(data[i].floodRisk);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = c);
      canvas.drawCircle(Offset(x, y), 3.5,
          Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

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

// ── Forecast Strip ────────────────────────────────────────────────────────────
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
          color: const Color(0xFF0a1828),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1e3a5f)),
        ),
        child: const Center(
          child: Text('⚠️ Forecast unavailable right now — check back soon',
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
                          color: Color(0xFF4a6080), fontSize: 8.5, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center),
                      Text(_emoji(precip), style: const TextStyle(fontSize: 18)),
                      Text('$temp°C', style: const TextStyle(
                          color: Color(0xFFe2eaf5), fontSize: 11, fontWeight: FontWeight.w700)),
                      Column(children: [
                        Container(height: 3,
                          decoration: BoxDecoration(
                              color: const Color(0xFF1e3a5f),
                              borderRadius: BorderRadius.circular(2)),
                          child: FractionallySizedBox(widthFactor: precipPct,
                              alignment: Alignment.centerLeft,
                              child: Container(decoration: BoxDecoration(
                                  color: pc, borderRadius: BorderRadius.circular(2))))),
                        const SizedBox(height: 3),
                        Text('${precip.toStringAsFixed(1)}mm',
                            style: TextStyle(color: pc, fontSize: 9, fontWeight: FontWeight.w600)),
                        Text('$wind km/h',
                            style: const TextStyle(color: Color(0xFF4a6080), fontSize: 8.5)),
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

// ── Pulsing Dot ───────────────────────────────────────────────────────────────
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
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
