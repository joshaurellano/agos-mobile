import 'package:flutter/material.dart';
import '../main.dart';
import '../models/data_source.dart';
import '../services/mock_data_service.dart';

class DataSourcesScreen extends StatelessWidget {
  const DataSourcesScreen({super.key});

  static const _statusInfo = {
    SourceStatus.live:      _StatusInfo('Live',      AppColors.green,  'Data stream active and current.'),
    SourceStatus.delayed:   _StatusInfo('Delayed',   AppColors.orange, 'Data is delayed beyond expected interval.'),
    SourceStatus.simulated: _StatusInfo('Simulated', AppColors.yellow, 'Prototype mode: data is simulated.'),
  };

  static const _sourceDescriptions = {
    'PAGASA Weather Station': 'Primary source for rainfall data, weather forecasts, and weather advisories for Bicol Region.',
    'Bicol River Gauge Station': 'PAGASA-managed river monitoring station tracking water levels along Bicol River.',
    'DOST-ASTI Flood Sensors': 'Manages flood early warning sensor networks across Bicol barangays.',
    'Local Barangay Sensor (Sim.)': 'Prototype placeholder for a proposed barangay-level IoT water sensor node.',
    'OCD Region V Advisory': 'Issues disaster risk management advisories and coordinates DRRM activities in Bicol.',
    'LGU Naga City Reports': 'Local Government Unit providing ground-truth reports and local situational updates.',
  };

  @override
  Widget build(BuildContext context) {
    final sources = MockDataService.dataSources;
    final liveCount    = sources.where((s) => s.status == SourceStatus.live).length;
    final delayedCount = sources.where((s) => s.status == SourceStatus.delayed).length;
    final simCount     = sources.where((s) => s.status == SourceStatus.simulated).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── KPIs ─────────────────────────────────────────────
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3, childAspectRatio: 1.4,
          mainAxisSpacing: 12, crossAxisSpacing: 12,
          children: [
            _KpiCard(icon: '📡', label: 'Sources Live',     value: '$liveCount/${sources.length}', color: AppColors.green),
            _KpiCard(icon: '⚠️', label: 'Delayed Sources',  value: '$delayedCount',                color: AppColors.orange),
            _KpiCard(icon: '🔬', label: 'Simulated',        value: '$simCount',                    color: AppColors.yellow),
          ],
        ),
        const SizedBox(height: 16),

        // ── Source Status Panel ───────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.blueCard, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.blueBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📡 Data Source Status Panel',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            ...sources.map((src) {
              final si = _statusInfo[src.status]!;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.blueMid,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.blueBorder),
                ),
                child: Row(children: [
                  Text(src.typeIcon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(src.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(si.desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: si.color)),
                      const SizedBox(width: 6),
                      Text(si.label, style: TextStyle(color: si.color, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                    Text('Updated: ${src.lastUpdate}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ]),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 16),

        // ── About Data Sources ────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.blueCard, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.blueBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ℹ️ About Data Sources',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            ...sources.map((src) {
              final desc = _sourceDescriptions[src.name] ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blueMid, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.blueBorder),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(src.typeIcon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(src.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
                    ]),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: const Text(
                '⚠️ Prototype Note: PAGASA data covers regional stations. Real-time hyper-local data for Barangay Triangulo specifically would require deployment of a dedicated IoT sensor node.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final String desc;
  const _StatusInfo(this.label, this.color, this.desc);
}

class _KpiCard extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  const _KpiCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.blueCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.blueBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 6),
      Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
    ]),
  );
}