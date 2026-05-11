import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import '../models/historical_flood.dart';
import '../services/mock_data_service.dart';

class HistoricalScreen extends StatefulWidget {
  const HistoricalScreen({super.key});

  @override
  State<HistoricalScreen> createState() => _HistoricalScreenState();
}

class _HistoricalScreenState extends State<HistoricalScreen> {
  int? _openId;
  String _filter = 'ALL';

  static const _colors = {
    FloodSeverity.critical: AppColors.red,
    FloodSeverity.warning:  AppColors.orange,
    FloodSeverity.advisory: AppColors.yellow,
    FloodSeverity.normal:   AppColors.green,
  };

  List<HistoricalFlood> get _filtered {
    if (_filter == 'ALL') return MockDataService.historicalFloods;
    return MockDataService.historicalFloods
        .where((f) => f.severityLabel == _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final floods = MockDataService.historicalFloods;
    final totalDisplaced = floods.fold(0, (s, f) => s + f.displaced);
    final avgDuration = floods.map((f) => f.durationHours).reduce((a, b) => a + b) / floods.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── KPIs ─────────────────────────────────────────────
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
          childAspectRatio: 1.4, mainAxisSpacing: 12, crossAxisSpacing: 12,
          children: [
            _KpiCard(icon: '📋', label: 'Flood Events Recorded',   value: '${floods.length}',       color: AppColors.accent),
            _KpiCard(icon: '🏘', label: 'Families Displaced',      value: '$totalDisplaced',         color: AppColors.orange),
            _KpiCard(icon: '⏱', label: 'Avg. Duration (hrs)',      value: avgDuration.toStringAsFixed(1), color: AppColors.yellow),
            _KpiCard(icon: '💧', label: 'Highest Water Level',     value: '6.0m',                   color: AppColors.red),
          ],
        ),
        const SizedBox(height: 16),

        // ── Bar Chart ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.blueCard, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.blueBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📊 Displaced Families per Flood Event',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(BarChartData(
                gridData: FlGridData(show: true,
                    getDrawingHorizontalLine: (_) => FlLine(color: AppColors.blueBorder, strokeWidth: 1),
                    getDrawingVerticalLine: (_) => FlLine(color: AppColors.blueBorder, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 36,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= floods.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          floods[i].typhoon.replaceAll('Typhoon ', '').replaceAll('Tropical Storm ', 'TS '),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 7),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: floods.asMap().entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [BarChartRodData(
                    toY: e.value.displaced.toDouble(),
                    color: AppColors.orange,
                    width: 24,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  )],
                )).toList(),
              )),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Events List ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.blueCard, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.blueBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('📋 Historical Flood Events Timeline',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: ['ALL', 'CRITICAL', 'WARNING', 'ADVISORY'].map((s) => GestureDetector(
                onTap: () => setState(() => _filter = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _filter == s ? AppColors.accent : AppColors.blueMid,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _filter == s ? AppColors.accent : AppColors.blueBorder),
                  ),
                  child: Text(s, style: TextStyle(
                    color: _filter == s ? AppColors.blueDark : AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w600,
                  )),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            ..._filtered.map((flood) {
              final color = _colors[flood.severity] ?? AppColors.accent;
              final isOpen = _openId == flood.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isOpen ? color.withOpacity(0.6) : AppColors.blueBorder),
                ),
                child: Column(children: [
                  // Header row
                  InkWell(
                    onTap: () => setState(() => _openId = isOpen ? null : flood.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(width: 10, height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(flood.typhoon, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                            Text(flood.date, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Text(flood.severityLabel, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Text('${flood.displaced} displaced', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(width: 8),
                        Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted, size: 18),
                      ]),
                    ),
                  ),
                  // Expanded detail
                  if (isOpen)
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      decoration: BoxDecoration(
                        color: AppColors.blueCard,
                        border: Border(top: BorderSide(color: color.withOpacity(0.3))),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 12),
                        Row(children: [
                          _DetailChip(label: 'Peak Level', value: flood.maxWaterLevel),
                          const SizedBox(width: 8),
                          _DetailChip(label: 'Duration', value: '${flood.durationHours} hrs'),
                          const SizedBox(width: 8),
                          _DetailChip(label: 'Casualties', value: flood.casualties == 0 ? '✅ None' : '${flood.casualties}'),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: flood.affectedZones.map((z) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                            ),
                            child: Text(z, style: const TextStyle(color: AppColors.accent, fontSize: 11)),
                          )).toList(),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.blueMid, borderRadius: BorderRadius.circular(8)),
                          child: Text('📝 ${flood.notes}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ),
                      ]),
                    ),
                ]),
              );
            }),
          ]),
        ),
      ]),
    );
  }
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

class _DetailChip extends StatelessWidget {
  final String label, value;
  const _DetailChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.blueMid, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 0.7, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    ),
  );
}