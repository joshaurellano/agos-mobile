import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import '../services/mock_data_service.dart';

class RainfallScreen extends StatefulWidget {
  const RainfallScreen({super.key});

  @override
  State<RainfallScreen> createState() => _RainfallScreenState();
}

class _RainfallScreenState extends State<RainfallScreen> {
  bool _showTable = false;
  bool _isHourly = true;

  late List<Map<String, dynamic>> _hourlyData;
  late List<Map<String, dynamic>> _dailyData;

  @override
  void initState() {
    super.initState();
    _hourlyData = MockDataService.generateHourlyRainfallData();
    _dailyData  = MockDataService.generateRainfallData();
  }

  List<Map<String, dynamic>> get _data => _isHourly ? _hourlyData : _dailyData;
  String get _xKey => _isHourly ? 'hour' : 'date';

  double get _total => _data.fold(0.0, (s, d) => s + (d['rainfall'] as double));
  double get _peak  => _data.map((d) => d['rainfall'] as double).reduce((a, b) => a > b ? a : b);

  String _intensity(double r) {
    if (r >= 50) return '🔴 Heavy';
    if (r >= 25) return '🟠 Moderate';
    if (r >= 10) return '🟡 Light';
    return '🟢 Trace';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── KPIs ─────────────────────────────────────────────
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
          childAspectRatio: 1.4,
          mainAxisSpacing: 12, crossAxisSpacing: 12,
          children: [
            _KpiCard(icon: '☔', label: 'Total Accumulated', value: '${_total.toStringAsFixed(1)}mm', color: AppColors.accent),
            _KpiCard(icon: '⚡', label: 'Peak Intensity', value: '${_peak.toStringAsFixed(1)}mm/hr', color: AppColors.orange),
            _KpiCard(icon: '⏱', label: '3-Hr Accumulation', value: '45.1mm', color: AppColors.yellow),
            _KpiCard(icon: '⚠️', label: 'PAGASA Threshold', value: '50mm', color: AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: 16),

        // ── Chart Card ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.blueCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.blueBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🌧 Rainfall Accumulation',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              _ToggleBtn(label: 'Hourly', active: _isHourly,  onTap: () => setState(() => _isHourly = true)),
              const SizedBox(width: 6),
              _ToggleBtn(label: 'Daily',  active: !_isHourly, onTap: () => setState(() => _isHourly = false)),
              const SizedBox(width: 6),
              _ToggleBtn(label: '📈', active: !_showTable, onTap: () => setState(() => _showTable = false)),
              const SizedBox(width: 6),
              _ToggleBtn(label: '📋', active: _showTable,  onTap: () => setState(() => _showTable = true)),
            ]),
            const SizedBox(height: 16),

            if (!_showTable)
              SizedBox(
                height: 260,
                child: BarChart(BarChartData(
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (_) => FlLine(color: AppColors.blueBorder, strokeWidth: 1),
                    getDrawingVerticalLine: (_) => FlLine(color: AppColors.blueBorder, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 36,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}mm',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                    )),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      interval: _isHourly ? 3 : 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= _data.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_data[i][_xKey] ?? '',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 8),
                              overflow: TextOverflow.ellipsis),
                        );
                      },
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(y: 50, color: AppColors.red, strokeWidth: 1.5, dashArray: [4, 2]),
                  ]),
                  barGroups: _data.asMap().entries.map((e) {
                    final rain = e.value['rainfall'] as double;
                    return BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(
                        toY: rain,
                        color: AppColors.accent,
                        width: _isHourly ? 8 : 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ]);
                  }).toList(),
                )),
              )
            else
              SingleChildScrollView(
                child: Table(
                  columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2)},
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.blueBorder))),
                      children: [_isHourly ? 'Hour' : 'Date', 'Rainfall (mm)', 'Intensity']
                          .map((h) => Padding(padding: const EdgeInsets.all(8),
                              child: Text(h, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600))))
                          .toList(),
                    ),
                    ..._data.map((row) {
                      final rain = row['rainfall'] as double;
                      return TableRow(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.blueBorder, width: 0.3))),
                        children: [
                          Padding(padding: const EdgeInsets.all(8), child: Text(row[_xKey] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8), child: Text('${rain}mm', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(_intensity(rain), style: const TextStyle(fontSize: 12))),
                        ],
                      );
                    }),
                  ],
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Legend ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blueCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.blueBorder),
          ),
          child: Wrap(
            spacing: 16, runSpacing: 8,
            children: [
              for (final r in [
                {'label': '🟢 Trace',         'range': '< 10mm/hr',   'color': AppColors.green},
                {'label': '🟡 Light Rain',    'range': '10–25mm/hr',  'color': AppColors.yellow},
                {'label': '🟠 Moderate Rain', 'range': '25–50mm/hr',  'color': AppColors.orange},
                {'label': '🔴 Heavy Rain',    'range': '≥ 50mm/hr',   'color': AppColors.red},
              ])
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(r['label'] as String, style: TextStyle(color: r['color'] as Color, fontSize: 12)),
                  const SizedBox(width: 4),
                  Text('(${r['range']})', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ]),
              const Text('Source: PAGASA · Naga City', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
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
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
    ]),
  );
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.blueMid,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? AppColors.accent : AppColors.blueBorder),
      ),
      child: Text(label, style: TextStyle(color: active ? AppColors.blueDark : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
    ),
  );
}