import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ─── Evacuation Centers (mirrors web FloodMapPage) ────────────────────────────
class _EvacCenter {
  final String id, name, type, note;
  final double lat, lng;
  final Color color;
  const _EvacCenter({
    required this.id,    required this.name,  required this.type,
    required this.note,  required this.lat,   required this.lng,
    required this.color,
  });
}

const _centers = [
  _EvacCenter(
    id: 'jesse-robredo',
    name: 'Jesse M. Robredo Coliseum',
    type: 'Primary Evacuation Center',
    note: 'Main evacuation center for Barangay Triangulo residents during flood events.',
    lat: 13.620122, lng: 123.188095,
    color: Color(0xFFDC143C),
  ),
  _EvacCenter(
    id: 'triangulo-elem',
    name: 'Triangulo Elementary School',
    type: 'School Evacuation Center',
    note: 'Secondary evacuation center located within the barangay proper.',
    lat: 13.6165193, lng: 123.1878926,
    color: Color(0xFFDC143C),
  ),
  _EvacCenter(
    id: 'jose-rizal-elem',
    name: 'Jose Rizal Elementary School',
    type: 'School Evacuation Center',
    note: 'Alternative evacuation center in the eastern section of the barangay.',
    lat: 13.6194395, lng: 123.1933071,
    color: Color(0xFFDC143C),
  ),
];

const _trianguloCenter = LatLng(13.6150, 123.1910);

const _boundary = [
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

// ─── Screen ───────────────────────────────────────────────────────────────────
class EvacuationScreen extends StatefulWidget {
  const EvacuationScreen({super.key});
  @override
  State<EvacuationScreen> createState() => _EvacuationScreenState();
}

class _EvacuationScreenState extends State<EvacuationScreen> {
  String? _openInfoId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Map ───────────────────────────────────────────────────────────
        Expanded(
          flex: 11,
          child: Stack(children: [
            FlutterMap(
              options: const MapOptions(
                initialCenter: _trianguloCenter,
                initialZoom: 14.5,
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.agos.app',
                ),
                // Barangay boundary — alert-color coded (mirroring web)
                PolygonLayer(polygons: [
                  Polygon(
                    points: _boundary,
                    color: const Color(0xFF38bdf8).withValues(alpha: 0.08),
                    borderColor: const Color(0xFF38bdf8).withValues(alpha: 0.7),
                    borderStrokeWidth: 2,
                  ),
                ]),
                // Evacuation markers
                MarkerLayer(
                  markers: _centers.map((c) => Marker(
                    point: LatLng(c.lat, c.lng),
                    width: 52, height: 52,
                    child: GestureDetector(
                      onTap: () => setState(() =>
                        _openInfoId = _openInfoId == c.id ? null : c.id),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name label above pin
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.color,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                            ),
                            child: Text(
                              c.name.split(' ').take(2).join(' '),
                              style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w700),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // SVG-style pin
                          CustomPaint(
                            size: const Size(20, 26),
                            painter: _PinPainter(color: c.color),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),

            // ── Info popup on marker tap ───────────────────────────────────
            if (_openInfoId != null)
              Positioned(
                bottom: 12, left: 12, right: 12,
                child: Builder(builder: (_) {
                  final c = _centers.firstWhere((c) => c.id == _openInfoId);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0d1f3c),
                        border: Border(
                          left: BorderSide(color: c.color, width: 3),
                          top: BorderSide(color: c.color.withValues(alpha: 0.4)),
                          right: BorderSide(color: c.color.withValues(alpha: 0.4)),
                          bottom: BorderSide(color: c.color.withValues(alpha: 0.4)),
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16)],
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: c.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: c.color.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.location_on_rounded, color: Color(0xFFDC143C), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.name, style: const TextStyle(
                            color: Color(0xFFe2eaf5), fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: c.color.withValues(alpha: 0.35)),
                            ),
                            child: Text(c.type, style: TextStyle(
                              color: c.color, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '📍 ${c.lat.toStringAsFixed(4)}, ${c.lng.toStringAsFixed(4)}',
                            style: const TextStyle(color: Color(0xFF4a6080), fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ])),
                        GestureDetector(
                          onTap: () => setState(() => _openInfoId = null),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, color: Color(0xFF4a6080), size: 16),
                          ),
                        ),
                      ]),
                    ),
                  );
                }),
              ),

            // ── Map legend ─────────────────────────────────────────────────
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1f3c).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1e3a5f)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 10, height: 10,
                      decoration: const BoxDecoration(color: Color(0xFFDC143C), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Evacuation Centers', style: TextStyle(color: Color(0xFF8da4be), fontSize: 9.5)),
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(width: 18, height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38bdf8).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(1),
                      )),
                    const SizedBox(width: 6),
                    const Text('Brgy. Boundary', style: TextStyle(color: Color(0xFF8da4be), fontSize: 9.5)),
                  ]),
                ]),
              ),
            ),

            // ── Click hint ─────────────────────────────────────────────────
            Positioned(
              top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1f3c).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF1e3a5f)),
                ),
                child: const Text('Tap marker for details',
                  style: TextStyle(color: Color(0xFF4a6080), fontSize: 9)),
              ),
            ),
          ]),
        ),

        // ── Detail cards ─────────────────────────────────────────────────────
        Expanded(
          flex: 13,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Section header
              const _SectionLabel(icon: '🏫', text: 'Evacuation Route Map — Barangay Triangulo'),
              const SizedBox(height: 12),

              // Center cards
              ..._centers.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CenterCard(center: c),
              )),

              // Warning notice
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf97316).withValues(alpha: 0.07),
                    border: Border(
                      left: const BorderSide(color: Color(0xFFf97316), width: 3),
                      top: BorderSide(color: const Color(0xFFf97316).withValues(alpha: 0.25)),
                      right: BorderSide(color: const Color(0xFFf97316).withValues(alpha: 0.25)),
                      bottom: BorderSide(color: const Color(0xFFf97316).withValues(alpha: 0.25)),
                    ),
                  ),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('⚠️  DURING A FLOOD EVENT', style: TextStyle(
                      color: Color(0xFFf97316), fontSize: 9.5,
                      fontWeight: FontWeight.w800, letterSpacing: 1.0,
                    )),
                    SizedBox(height: 6),
                    Text(
                      'Proceed immediately to the nearest designated evacuation center. '
                      'Bring essential documents, medicines, and supplies. '
                      'Follow instructions from Barangay Officials.',
                      style: TextStyle(color: Color(0xFF8da4be), fontSize: 11.5, height: 1.5),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Center Detail Card ────────────────────────────────────────────────────────
class _CenterCard extends StatelessWidget {
  final _EvacCenter center;
  const _CenterCard({required this.center});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1f3c),
        border: Border(
          left: BorderSide(color: center.color, width: 3),
          top: const BorderSide(color: Color(0xFF1e3a5f)),
          right: const BorderSide(color: Color(0xFF1e3a5f)),
          bottom: const BorderSide(color: Color(0xFF1e3a5f)),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('🏫 ${center.name}', style: const TextStyle(
              color: Color(0xFFe2eaf5), fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ]),
        const SizedBox(height: 7),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: center.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: center.color.withValues(alpha: 0.35)),
            ),
            child: Text(center.type, style: TextStyle(
              color: center.color, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(center.note, style: const TextStyle(
          color: Color(0xFF8da4be), fontSize: 12, height: 1.5)),
        const SizedBox(height: 10),
        // Coordinates row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF0a1828),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF1e3a5f)),
          ),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, color: Color(0xFF4a6080), size: 14),
            const SizedBox(width: 6),
            Text(
              '${center.lat.toStringAsFixed(4)}, ${center.lng.toStringAsFixed(4)}',
              style: const TextStyle(
                color: Color(0xFF4a6080), fontSize: 11, fontFamily: 'monospace'),
            ),
          ]),
        ),
      ]),
    ),
  );
}

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String icon, text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(icon, style: const TextStyle(fontSize: 12)),
    const SizedBox(width: 6),
    Flexible(
      child: Text(text.toUpperCase(), style: const TextStyle(
        color: Color(0xFF4a6080), fontSize: 9.5,
        fontWeight: FontWeight.w800, letterSpacing: 1.2,
      )),
    ),
    const SizedBox(width: 8),
    Expanded(child: Container(height: 1, color: const Color(0xFF1e3a5f))),
  ]);
}

// ── Custom Pin Painter ────────────────────────────────────────────────────────
class _PinPainter extends CustomPainter {
  final Color color;
  const _PinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Teardrop path — use ui.Path to avoid flutter_map's Path<LatLng> conflict
    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..cubicTo(
        size.width / 2 - 2, size.height * 0.8,
        0, size.height * 0.6,
        0, size.height * 0.42,
      )
      ..arcToPoint(
        Offset(size.width, size.height * 0.42),
        radius: Radius.circular(size.width / 2),
        clockwise: false,
      )
      ..cubicTo(
        size.width, size.height * 0.6,
        size.width / 2 + 2, size.height * 0.8,
        size.width / 2, size.height,
      )
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);

    // Inner circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.38),
      size.width * 0.22,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.color != color;
}