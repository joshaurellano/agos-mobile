// flood_map_screen.dart
//
// AGOS's dedicated, full-screen home for the flood situation map. Mirrors
// the web dashboard's map card: a segmented "2D Map / 3D View" toggle over
// the barangay flood-zone map (color-coded by current alert level), with the
// same vertical map-tool stack (zoom / locate / layers) used elsewhere.
//
// The old "Live Radar" (Windy embed) layer has been removed entirely — this
// screen no longer depends on webview_flutter.
//
// "3D View" implementation note:
// The live, interactive FlutterMap widget is ALWAYS mounted with a stable
// key and is NEVER wrapped in a Transform/IgnorePointer that changes its
// ancestor chain — doing that previously caused flutter_map's element to be
// torn down/reparented on every toggle, which under race conditions with the
// periodic status timer produced "Looking up a deactivated widget's ancestor
// is unsafe" crashes.
//
// Instead, "3D View" captures a still image of the currently-rendered map
// (via RepaintBoundary.toImage()) and applies the perspective tilt to that
// static image in a completely separate overlay widget. The real map keeps
// living underneath, untouched, the whole time. A small animated isometric
// bar overlay on top shows the live flood probability.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:http/http.dart' as http;
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

class _FloodMapScreenState extends State<FloodMapScreen>
    with SingleTickerProviderStateMixin {
  // '2d' = flat interactive map, '3d' = tilted snapshot + risk-bar overlay
  String _layer = '2d';

  String _alertKey = 'NORMAL';
  double? _probability;
  bool _loading = true;
  DateTime _lastUpdated = DateTime.now();
  Timer? _timer;

  bool _showLegend = false;
  double _zoom = 14.5;
  final MapController _mapController = MapController();

  // Key on the RepaintBoundary that wraps the live map, used to grab a
  // still image of it for the 3D tilt effect.
  final GlobalKey _mapBoundaryKey = GlobalKey();
  ui.Image? _mapSnapshot;
  bool _capturingSnapshot = false;

  // Slow continuous drift used to animate the 3D risk-bar (and give the
  // tilted view a subtle sense of life without needing touch gestures).
  late final AnimationController _driftCtrl;

  @override
  void initState() {
    super.initState();
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _driftCtrl.dispose();
    _mapSnapshot?.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    if (!mounted) return;
    try {
      final res = await http.get(Uri.parse(_modelUrl)).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final level = (j['alert_level'] as num?)?.toInt() ?? 0;
        final prob  = (j['probability'] as num?)?.toDouble();
        if (!mounted) return;
        setState(() {
          _alertKey     = _alertKeyFromInt(level);
          _probability  = prob;
          _loading      = false;
          _lastUpdated  = DateTime.now();
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _zoomBy(double delta) {
    if (!mounted) return;
    final target = (_zoom + delta).clamp(12.0, 19.0);
    setState(() => _zoom = target);
    try {
      _mapController.move(_mapController.camera.center, target);
      if (_layer == '3d') _captureMapSnapshot();
    } catch (_) {
      // Map not currently attached — safe to ignore.
    }
  }

  void _recenter() {
    if (!mounted) return;
    setState(() => _zoom = 14.5);
    try {
      _mapController.move(_trianguloCenter, _zoom);
      if (_layer == '3d') _captureMapSnapshot();
    } catch (_) {
      // Map not currently attached — safe to ignore.
    }
  }

  void _selectLayer(String layer) {
    if (_layer == layer) return;
    setState(() => _layer = layer);
    if (layer == '3d') _captureMapSnapshot();
  }

  // Grabs a still image of the currently-rendered map for the 3D tilt.
  // The live FlutterMap widget itself is never touched/transformed — only
  // this snapshot image is, so the interactive map's element is never at
  // risk of being torn down mid-frame.
  Future<void> _captureMapSnapshot() async {
    if (!mounted) return;
    setState(() => _capturingSnapshot = true);
    try {
      // Give tiles a moment to finish painting before snapshotting them.
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final renderObject = _mapBoundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        if (mounted) setState(() => _capturingSnapshot = false);
        return;
      }

      final image = await renderObject.toImage(pixelRatio: 1.5);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _mapSnapshot?.dispose();
        _mapSnapshot = image;
        _capturingSnapshot = false;
      });
    } catch (_) {
      if (mounted) setState(() => _capturingSnapshot = false);
    }
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
                label: '2D Map',
                selected: _layer == '2d',
                onTap: () => _selectLayer('2d'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LayerTab(
                icon: Icons.view_in_ar_rounded,
                label: '3D View',
                selected: _layer == '3d',
                onTap: () => _selectLayer('3d'),
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
                child: _buildMap(color, is3D: _layer == '3d'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  // ── Map (shared 2D/3D render) ───────────────────────────────────────────
  Widget _buildMap(Color color, {required bool is3D}) {
    // The live, interactive map. Stable key + never wrapped in a Transform —
    // its ancestor chain is identical every single build, in 2D or 3D mode.
    final liveMap = RepaintBoundary(
      key: _mapBoundaryKey,
      child: FlutterMap(
        key: const ValueKey('agos_flood_map'),
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _trianguloCenter,
          initialZoom: _zoom,
          // Real pan/zoom always stays on this flat map. In 3D mode it's
          // simply hidden underneath the tilted snapshot overlay, so we
          // disable touch on it rather than remove/rebuild it.
          interactionOptions: InteractionOptions(
            flags: is3D
                ? InteractiveFlag.none
                : (InteractiveFlag.pinchZoom | InteractiveFlag.drag),
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
    );

    return Stack(children: [
      // Real map always mounted underneath, untouched.
      Positioned.fill(child: ColoredBox(color: AppColors.bgDark, child: liveMap)),

      // 3D overlay: a separate, freely add/removable widget — safe because
      // it holds no long-lived controllers, just a still image + a painter.
      if (is3D)
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: AppColors.bgDark,
              child: _mapSnapshot != null
                  ? Transform(
                      alignment: FractionalOffset.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016) // perspective depth
                        ..rotateX(1.05),          // ~60° tilt
                      child: RawImage(image: _mapSnapshot, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                      ),
                    ),
            ),
          ),
        ),

      // Floating isometric bar showing live flood-probability magnitude.
      if (is3D)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _driftCtrl,
            builder: (context, _) => CustomPaint(
              painter: _RiskBarPainter(
                color: color,
                probability: _probability ?? 0,
                phase: _driftCtrl.value * 2 * math.pi,
              ),
            ),
          ),
        ),

      // ── Status bar ───────────────────────────────────────────────────────
      Positioned(top: 10, left: 10, right: 58, child: _statusPill(color)),

      // ── Legend panel ─────────────────────────────────────────────────────
      if (_showLegend) Positioned(top: 62, right: 56, child: _legendPanel()),

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
      Positioned(bottom: 10, left: 10, right: 10, child: _captionBar(is3D)),
    ]);
  }

  // ── Shared UI pieces ────────────────────────────────────────────────────
  Widget _statusPill(Color color) {
    return Container(
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
        if (_loading || _capturingSnapshot)
          const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 1.5),
          ),
      ]),
    );
  }

  Widget _legendPanel() {
    return Container(
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
    );
  }

  Widget _captionBar(bool is3D) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.bgDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgBorder),
      ),
      child: Text(
        is3D
            ? 'Tilted 3D view · bar height reflects live flood probability'
            : 'Approximate barangay boundary · color-coded by current water code',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5),
      ),
    );
  }
}

// ── Isometric risk-bar painter (3D view overlay) ────────────────────────────
//
// Draws a small extruded box near the center of the tilted map whose height
// scales with the live flood probability and whose color matches the current
// alert level. `phase` drives a gentle azimuth sway so the box doesn't look
// static, without needing any touch/rotation gesture.
class _RiskBarPainter extends CustomPainter {
  final Color color;
  final double probability; // 0..1
  final double phase;

  _RiskBarPainter({required this.color, required this.probability, required this.phase});

  Offset _iso(double x, double y, double z, Offset origin) {
    const cos30 = 0.8660254;
    const sin30 = 0.5;
    final sx = (x - z) * cos30;
    final sy = (x + z) * sin30 - y;
    return origin + Offset(sx, sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.60);

    final spin = math.sin(phase) * 0.35; // gentle sway, radians
    final cosS = math.cos(spin), sinS = math.sin(spin);

    double rx(double x, double z) => x * cosS - z * sinS;
    double rz(double x, double z) => x * sinS + z * cosS;

    const halfW = 20.0, halfD = 13.0;
    final h = 26.0 + probability.clamp(0.0, 1.0) * 150.0;

    Offset p(double x, double y, double z) => _iso(rx(x, z), y, rz(x, z), origin);

    final a  = p(-halfW, 0, -halfD);
    final b  = p(halfW, 0, -halfD);
    final c  = p(halfW, 0, halfD);
    final d  = p(-halfW, 0, halfD);
    final a2 = p(-halfW, h, -halfD);
    final b2 = p(halfW, h, -halfD);
    final c2 = p(halfW, h, halfD);
    final d2 = p(-halfW, h, halfD);

    // Ground shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(center: origin + const Offset(0, 4), width: 60, height: 22),
      shadowPaint,
    );

    void face(List<Offset> pts, Color fill) {
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }

    face([a, b, b2, a2], Color.lerp(color, Colors.black, 0.42)!); // left/front face
    face([b, c, c2, b2], Color.lerp(color, Colors.black, 0.22)!); // right face
    face([a2, b2, c2, d2], color);                                 // top face

    // Probability readout floating above the bar.
    final pct = (probability.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    final tp = TextPainter(
      text: TextSpan(
        text: '$pct%',
        style: TextStyle(
          color: color, fontSize: 12, fontWeight: FontWeight.w800,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final topCenter = Offset((a2.dx + c2.dx) / 2, (a2.dy + c2.dy) / 2);
    tp.paint(canvas, topCenter + Offset(-tp.width / 2, -tp.height - 10));
  }

  @override
  bool shouldRepaint(covariant _RiskBarPainter oldDelegate) =>
      oldDelegate.probability != probability ||
      oldDelegate.color != color ||
      oldDelegate.phase != phase;
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