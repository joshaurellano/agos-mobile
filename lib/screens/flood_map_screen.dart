import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

  static const LatLng _center = LatLng(13.6192, 123.1814);

  FloodZone get _selectedZone =>
      MockDataService.floodZones.firstWhere((z) => z.id == _activeZone);

  String _proximityText(String id) {
    if (id == 'Z3') return '⚠️ Yes (< 200m)';
    if (id == 'Z2') return '≈ 400m';
    return '> 600m';
  }

  String _riskDesc(FloodRisk risk) {
    switch (risk) {
      case FloodRisk.high:
        return '⚠️ This zone is at HIGH risk of flooding. It is the nearest to the Bicol River bank. Preemptive evacuation is recommended when water level exceeds 3.5m.';
      case FloodRisk.moderate:
        return 'ℹ️ This zone has moderate flood risk due to proximity to drainage channels. Monitor during heavy rainfall events.';
      default:
        return 'ℹ️ This zone has low flood risk. Occasional waterlogging possible during extreme rainfall.';
    }
  }

  void _showEvacuateDialog(FloodZone zone) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.blueDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '🚨 Evacuate ${zone.name}?',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Send evacuation order for ${zone.name} — ${zone.households} households will be notified.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '✅ ${zone.households} households in ${zone.name} have been notified.'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Map Card ──────────────────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🗺 Color-Coded Flood Zone Map',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 300,
                    child: FlutterMap(
                      options: const MapOptions(
                        initialCenter: _center,
                        initialZoom: 16,
                        interactionOptions: InteractionOptions(
                          flags: InteractiveFlag.pinchZoom |
                              InteractiveFlag.drag,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          maxZoom: 20,
                          userAgentPackageName: 'com.agos.floodmonitor',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _center,
                              width: 200,
                              height: 70,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.blueDark
                                          .withOpacity(0.9),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                          color: AppColors.accent
                                              .withOpacity(0.6)),
                                    ),
                                    child: const Text(
                                      'Barangay Triangulo\nFlood Monitoring Station',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.location_pin,
                                      color: AppColors.accent, size: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Simulated map · Data from PAGASA & OCD Region V',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Selected Zone Detail Card ─────────────────────────
          _Card(
            border:
                Border.all(color: zone.color.withOpacity(0.5), width: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${zone.name} — Details',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Flood Risk',
                  child: _Badge(label: zone.riskLabel, color: zone.color),
                ),
                _DetailRow(
                  label: 'Households',
                  child: Text(
                    '${zone.households}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                _DetailRow(
                  label: 'Est. Residents',
                  child: Text(
                    '${zone.estimatedResidents}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                _DetailRow(
                  label: 'Near Bicol River',
                  child: Flexible(
                    child: Text(
                      _proximityText(zone.id),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: zone.id == 'Z3'
                            ? AppColors.orange
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blueMid,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _riskDesc(zone.risk),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
                if (!isResident) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showEvacuateDialog(zone),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        '🚨 Evacuate ${zone.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── All Zones Summary ─────────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 All Zones Summary',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                ...MockDataService.floodZones.map((z) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _activeZone = z.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeZone == z.id
                                ? z.color.withOpacity(0.1)
                                : AppColors.blueMid,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _activeZone == z.id
                                  ? z.color.withOpacity(0.5)
                                  : AppColors.blueBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: z.color,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  z.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _Badge(label: z.riskLabel, color: z.color),
                              const Spacer(),
                              Text(
                                '${z.households} HH',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card wrapper ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final BoxBorder? border;
  const _Card({required this.child, this.border});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.blueCard,
          borderRadius: BorderRadius.circular(10),
          border: border ?? Border.all(color: AppColors.blueBorder),
        ),
        child: child,
      );
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(width: 12),
            child,
          ],
        ),
      );
}

// ── Badge ─────────────────────────────────────────────────────────────────────

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
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
}