// flood_map_screen.dart
//
// AGOS's answer to PANaHON's "Radar" tab: a dedicated, full-screen home for
// every map-shaped view of the flood situation. The barangay flood-zone map
// (color-coded by current alert level) and the live rain radar — both of
// which used to live as cards further down the Dashboard scroll — now share
// this page behind a simple segmented toggle, with the same vertical
// map-tool stack (zoom / locate / layers) used on the Evacuation screen.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../main.dart';
import '../theme/panahon_ui.dart';

// ─── URL (same backend + fallback used across the app) ────────────────────────
const _fallbackBaseUrl = 'https://flood-api-553657561163.asia-southeast1.run.app';
String get _modelUrl => dotenv.env['MODEL_API_URL'] ?? '$_fallbackBaseUrl/api/predict-flood';

// ─── Alert colors / labels ──────────────────────────────────────────────────────
const _alertColors = {
  'NORMAL':   Color(0xFF22c55e),
  'ADVISORY': Color(0xFFeab308),
  'WARNING':  Color(0xFFf97316),
  'CRITICAL': Color(0xFFef4444),
};

const _alertLevelKeys = ['NORMAL', 'ADVISORY', 'WARNING', 'CRITICAL'];

String _alertKeyFromInt(int level) {
  switch (level) {
    case 3:  return 'CRITICAL';
    case 2:  return 'WARNING';
    case 1:  return 'ADVISORY';
    default: return 'NORMAL';
  }
}

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

const _trianguloCenter = LatLng(13.6140, 123.1915);

// ─── Screen ───────────────────────────────────────────────────────────────────
class FloodMapScreen extends StatefulWidget {
  const FloodMapScreen({super.key});

  @override
  State<FloodMapScreen> createState() => _FloodMapScreenState();
}

class _FloodMapScreenState extends State<FloodMapScreen> {
  // 'zone' = flood status map, 'radar' = live Windy radar
  String _layer = 'zone';

  String _alertKey = 'NORMAL';
  double? _probability;
  bool _loading = true;
  DateTime _lastUpdated = DateTime.now();
  Timer? _timer;

  bool _showLegend = false;
  double _zoom = 14.5;
  final MapController _mapController = MapController();

  late final WebViewController _windyCtrl;

  @override
  void initState() {
    super.initState();
    _windyCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF091729))
      ..loadRequest(Uri.parse(
          'https://www.windy.com/embed2.html?lat=13.621&lon=123.194&zoom=8&level=surface&overlay=rain&product=ecmwf&message=true&marker=true&location=coordinates'));
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final res = await http.get(Uri.parse(_modelUrl)).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final level = (j['alert_level'] as num?)?.toInt() ?? 0;
        final prob  = (j['probability'] as num?)?.toDouble();
        setState(() {
          _alertKey     = _alertKeyFromInt(level);
          _probability  = prob;
          _loading      = false;
          _lastUpdated  = DateTime.now();
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _zoomBy(double delta) {
    final target = (_zoom + delta).clamp(12.0, 19.0);
    setState(() => _zoom = target);
    _mapController.move(_mapController.camera.center, target);
  }

  void _recenter() {
    setState(() => _zoom = 14.5);
    _mapController.move(_trianguloCenter, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    final color = _alertColors[_alertKey] ?? _alertColors['NORMAL']!;

    return Column(
      children: [
        // ── Segmented layer toggle ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            Expanded(
              child: _LayerTab(
                icon: Icons.map_rounded,
                label: 'Flood Zone',
                selected: _layer == 'zone',
                onTap: () => setState(() => _layer = 'zone'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LayerTab(
                icon: Icons.satellite_alt_rounded,
                label: 'Live Radar',
                selected: _layer == 'radar',
                onTap: () => setState(() => _layer = 'radar'),
              ),
            ),
          ]),
        ),

        // ── Map area ───────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1e3a5f)),
                ),
                child: _layer == 'zone' ? _buildZoneMap(color) : _buildRadar(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  // ── Flood zone map ────────────────────────────────────────────────────────
  Widget _buildZoneMap(Color color) {
    return Stack(children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _trianguloCenter,
          initialZoom: _zoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.agos.floodmonitoring',
            tileBuilder: (context, tileWidget, tile) => ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                -0.2126, -0.7152, -0.0722, 0, 255,
                -0.2126, -0.7152, -0.0722, 0, 255,
                -0.2126, -0.7152, -0.0722, 0, 255,
                 0,       0,       0,       1,   0,
              ]),
              child: tileWidget,
            ),
          ),
          PolygonLayer(polygons: [
            Polygon(
              points: _trianguloPolygon,
              color: color.withValues(alpha: 0.28),
              borderColor: color,
              borderStrokeWidth: 2.0,
            ),
          ]),
        ],
      ),

      // ── Status bar (PANaHON-style floating pill) ───────────────────────
      Positioned(
        top: 10, left: 10, right: 58,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.bgDark.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10)],
          ),
          child: Row(children: [
            Container(
              width: 9, height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Brgy. Triangulo · $_alertKey', style: TextStyle(
                    color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
                if (_probability != null)
                  Text('${(_probability! * 100).toStringAsFixed(0)}% flood probability',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
              ]),
            ),
            if (_loading)
              const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 1.5),
              ),
          ]),
        ),
      ),

      // ── Legend panel ─────────────────────────────────────────────────────
      if (_showLegend)
        Positioned(
          top: 62, right: 56,
          child: Container(
            width: 168,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.bgDark.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.bgBorder),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('WATER CODE LEGEND', style: TextStyle(
                  color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              ..._alertLevelKeys.map((key) {
                final c = _alertColors[key]!;
                final isCur = key == _alertKey;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 7),
                    Expanded(child: Text(key, style: TextStyle(
                        color: isCur ? c : AppColors.textSec,
                        fontSize: 10.5,
                        fontWeight: isCur ? FontWeight.w800 : FontWeight.w500))),
                    if (isCur)
                      const Icon(Icons.check_circle_rounded, color: AppColors.textSec, size: 12),
                  ]),
                );
              }),
              const SizedBox(height: 2),
              const Text('Barangay boundary shaded by current level',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
            ]),
          ),
        ),

      // ── Vertical map tool stack ──────────────────────────────────────────
      Positioned(
        top: 62,
        right: 10,
        child: MapToolStack(children: [
          MapToolButton(
            icon: Icons.layers_rounded,
            active: _showLegend,
            onTap: () => setState(() => _showLegend = !_showLegend),
          ),
          MapToolButton(icon: Icons.my_location_rounded, onTap: _recenter),
          MapToolButton(icon: Icons.add_rounded, onTap: () => _zoomBy(1)),
          MapToolButton(icon: Icons.remove_rounded, onTap: () => _zoomBy(-1)),
        ]),
      ),

      // ── Caption ───────────────────────────────────────────────────────────
      Positioned(
        bottom: 10, left: 10, right: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.bgDark.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.bgBorder),
          ),
          child: const Text('Approximate barangay boundary · color-coded by current water code',
              style: TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
        ),
      ),
    ]);
  }

  // ── Live radar ─────────────────────────────────────────────────────────────
  Widget _buildRadar() => Stack(children: [
    WebViewWidget(controller: _windyCtrl),
    Positioned(
      top: 10, left: 10, right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.bgDark.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bgBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10)],
        ),
        child: const Row(children: [
          Icon(Icons.satellite_alt_rounded, color: AppColors.accent, size: 15),
          SizedBox(width: 8),
          Expanded(
            child: Text('Live rain radar over Naga City',
                style: TextStyle(color: AppColors.textPri, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    ),
  ]);
}

// ── Segmented layer tab ───────────────────────────────────────────────────────
class _LayerTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LayerTab({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent.withValues(alpha: 0.14) : AppColors.bgCard,
        border: Border.all(color: selected ? AppColors.accent.withValues(alpha: 0.5) : AppColors.bgBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: selected ? AppColors.accent : AppColors.textMuted),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
          color: selected ? AppColors.accent : AppColors.textMuted,
          fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        )),
      ]),
    ),
  );
}
