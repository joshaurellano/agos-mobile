import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/flood_zone.dart';
import '../services/auth_service.dart';
import '../services/mock_data_service.dart';

class FloodMapScreen extends StatefulWidget {
  const FloodMapScreen({super.key});

  @override
  State<FloodMapScreen> createState() => _FloodMapScreenState();
}

class _FloodMapScreenState extends State<FloodMapScreen> {
  String _activeZone = 'Z3';

  FloodZone get _selectedZone =>
      MockDataService.floodZones.firstWhere((z) => z.id == _activeZone);

  String _proximityText(String id) {
    if (id == 'Z3') return '⚠️ Yes (< 200m)';
    if (id == 'Z2') return '≈ 400m';
    return '> 600m';
  }

  String _riskDesc(FloodRisk risk) {
    switch (risk) {
      case FloodRisk.high:     return '⚠️ This zone is at HIGH risk of flooding. It is the nearest to the Bicol River bank. Preemptive evacuation is recommended when water level exceeds 3.5m.';
      case FloodRisk.moderate: return 'ℹ️ This zone has moderate flood risk due to proximity to drainage channels. Monitor during heavy rainfall events.';
      default:                 return 'ℹ️ This zone has low flood risk. Occasional waterlogging possible during extreme rainfall.';
    }
  }

  void _showEvacuateDialog(FloodZone zone) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.blueDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('🚨 Evacuate ${zone.name}?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Send evacuation order for ${zone.name} — ${zone.households} households will be notified.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('✅ ${zone.households} households in ${zone.name} have been notified.'),
                backgroundColor: AppColors.green,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Send Evacuation Order'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isResident = user?.isResident ?? false;
    final zone = _selectedZone;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (_, constraints) {
        final wide = constraints.maxWidth > 600;
        return Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Map ──────────────────────────────────────────
            Flexible(
              flex: wide ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.blueCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blueBorder),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('🗺 Color-Coded Flood Zone Map',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTapDown: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      final localPos = details.localPosition;
                      // Simple zone hit-test based on approximate SVG zones scaled to widget
                      final size = box.size;
                      final w = size.width;
                      final h = 240.0;
                      final x = localPos.dx, y = localPos.dy;
                      // Z1: top-left, Z2: top-right, Z3: bottom-left, Z4: bottom-right
                      if (y < h * 0.47) {
                        setState(() => _activeZone = x < w * 0.5 ? 'Z1' : 'Z2');
                      } else {
                        setState(() => _activeZone = x < w * 0.6 ? 'Z3' : 'Z4');
                      }
                    },
                    child: CustomPaint(
                      size: Size(double.infinity, 240),
                      painter: _FloodMapPainter(activeZone: _activeZone),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Tap a zone to select  ·  Data from PAGASA & OCD Region V',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ),
                ]),
              ),
            ),
            SizedBox(width: wide ? 12 : 0, height: wide ? 0 : 12),

            // ── Detail ───────────────────────────────────────
            Flexible(
              flex: wide ? 1 : 0,
              child: Column(children: [
                // Selected zone card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.blueCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: zone.color.withOpacity(0.5), width: 2),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${zone.name} — Details',
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Flood Risk', child: _Badge(label: zone.riskLabel, color: zone.color)),
                    _DetailRow(label: 'Households', child: Text('${zone.households}',
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700))),
                    _DetailRow(label: 'Est. Residents', child: Text('${zone.estimatedResidents}',
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700))),
                    _DetailRow(label: 'Near Bicol River', child: Text(_proximityText(zone.id),
                        style: TextStyle(color: zone.id == 'Z3' ? AppColors.orange : AppColors.textPrimary, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.blueMid,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_riskDesc(zone.risk),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    if (!isResident) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showEvacuateDialog(zone),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('🚨 Evacuate ${zone.name}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),

                // All zones summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.blueCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.blueBorder),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('📊 All Zones Summary',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 12),
                    ...MockDataService.floodZones.map((z) => GestureDetector(
                      onTap: () => setState(() => _activeZone = z.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeZone == z.id ? z.color.withOpacity(0.1) : AppColors.blueMid,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _activeZone == z.id ? z.color.withOpacity(0.5) : AppColors.blueBorder,
                          ),
                        ),
                        child: Row(children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: z.color)),
                          const SizedBox(width: 10),
                          Text(z.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(width: 8),
                          _Badge(label: z.riskLabel, color: z.color),
                          const Spacer(),
                          Text('${z.households} HH', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ]),
                      ),
                    )),
                  ]),
                ),
              ]),
            ),
          ],
        );
      }),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      child,
    ]),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

class _FloodMapPainter extends CustomPainter {
  final String activeZone;
  const _FloodMapPainter({required this.activeZone});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bg = Paint()..color = const Color(0xFF0A1628);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(8)), bg);

    // Zone colors
    final zones = [
      {'id': 'Z1', 'color': 0xFF22C55E, 'rect': Rect.fromLTRB(w * 0.15, h * 0.10, w * 0.50, h * 0.47), 'label': 'Zone 1', 'risk': 'LOW'},
      {'id': 'Z2', 'color': 0xFFEAB308, 'rect': Rect.fromLTRB(w * 0.50, h * 0.10, w * 0.85, h * 0.47), 'label': 'Zone 2', 'risk': 'MODERATE'},
      {'id': 'Z3', 'color': 0xFFF97316, 'rect': Rect.fromLTRB(w * 0.15, h * 0.47, w * 0.65, h * 0.88), 'label': 'Zone 3', 'risk': 'HIGH'},
      {'id': 'Z4', 'color': 0xFF22C55E, 'rect': Rect.fromLTRB(w * 0.65, h * 0.47, w * 0.85, h * 0.88), 'label': 'Zone 4', 'risk': 'LOW'},
    ];

    for (final z in zones) {
      final c = Color(z['color'] as int);
      final rect = z['rect'] as Rect;
      final isActive = z['id'] == activeZone;

      // Fill
      canvas.drawRect(rect, Paint()..color = c.withOpacity(isActive ? 0.35 : 0.18));
      // Border
      canvas.drawRect(rect, Paint()
        ..color = c.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 2.5 : 1.5);

      // Label
      final labelPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: '${z['label']}\n', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11)),
            TextSpan(text: z['risk'] as String, style: TextStyle(color: c.withOpacity(0.8), fontSize: 9)),
          ],
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      labelPainter.paint(canvas, Offset(
        rect.center.dx - labelPainter.width / 2,
        rect.center.dy - labelPainter.height / 2,
      ));
    }

    // River
    final riverPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, h * 0.6)
      ..quadraticBezierTo(w * 0.2, h * 0.56, w * 0.45, h * 0.62)
      ..quadraticBezierTo(w * 0.7, h * 0.58, w, h * 0.65);
    canvas.drawPath(path, riverPaint);

    // Header
    final headerPainter = TextPainter(
      text: const TextSpan(
        text: 'BARANGAY TRIANGULO, NAGA CITY',
        style: TextStyle(color: Color(0xFF4A6080), fontSize: 8, letterSpacing: 1.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    headerPainter.paint(canvas, Offset(w / 2 - headerPainter.width / 2, 8));
  }

  @override
  bool shouldRepaint(covariant _FloodMapPainter old) => old.activeZone != activeZone;
}