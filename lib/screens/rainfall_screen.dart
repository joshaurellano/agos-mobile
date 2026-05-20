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
  bool _isHourly  = true;

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

  double get _total =>
      _data.fold(0.0, (s, d) => s + (d['rainfall'] as double));
  double get _peak =>
      _data.map((d) => d['rainfall'] as double).reduce((a, b) => a > b ? a : b);

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
        // ── KPIs ───────────────────────────────────────────────
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
              _KpiCard(icon: '☔', label: 'Total Accumulated', value: '${_total.toStringAsFixed(1)}mm', color: AppColors.accent),
              _KpiCard(icon: '⚡', label: 'Peak Intensity',    value: '${_peak.toStringAsFixed(1)}mm/hr', color: AppColors.orange),
              _KpiCard(icon: '⏱', label: '3-Hr Accumulation', value: '45.1mm', color: AppColors.yellow),
              _KpiCard(icon: '⚠️', label: 'PAGASA Threshold', value: '50mm',   color: AppColors.textSecondary),
            ],
          );
        }),
        const SizedBox(height: 16),

        // ── Chart Card ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.blueCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.blueBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Toolbar — wraps on narrow screens
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('🌧 Rainfall Accumulation',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const Spacer(),
                _ToggleBtn(label: 'Hourly', active: _isHourly,  onTap: () => setState(() => _isHourly = true)),
                _ToggleBtn(label: 'Daily',  active: !_isHourly, onTap: () => setState(() => _isHourly = false)),
                _ToggleBtn(label: '📈',     active: !_showTable, onTap: () => setState(() => _showTable = false)),
                _ToggleBtn(label: '📋',     active: _showTable,  onTap: () => setState(() => _showTable = true)),
              ],
            ),
            const SizedBox(height: 16),

            if (!_showTable)
              SizedBox(
                height: 260,
                child: BarChart(BarChartData(
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: AppColors.blueBorder, strokeWidth: 1),
                    getDrawingVerticalLine: (_) =>
                        FlLine(color: AppColors.blueBorder, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}mm',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 9)),
                    )),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= _data.length || i % 4 != 0)
                          return const SizedBox();
                        return Text(
                          _data[i][_xKey]?.toString() ?? '',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 9),
                        );
                      },
                    )),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: _data.asMap().entries.map((e) {
                    final rainfall = e.value['rainfall'] as double;
                    final color = rainfall >= 50
                        ? AppColors.red
                        : rainfall >= 25
                            ? AppColors.orange
                            : AppColors.accent;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: rainfall,
                          color: color,
                          width: _isHourly ? 6 : 16,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                        ),
                      ],
                    );
                  }).toList(),
                )),
              )
            else
              // Table view
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  border: TableBorder.all(
                      color: AppColors.blueBorder, width: 1),
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                          color: AppColors.blueMid),
                      children: [
                        _TH(_isHourly ? 'Hour' : 'Date'),
                        _TH('Rainfall (mm)'),
                        _TH('Intensity'),
                      ],
                    ),
                    ..._data.take(24).map((row) {
                      final r = row['rainfall'] as double;
                      return TableRow(children: [
                        _TD(row[_xKey]?.toString() ?? ''),
                        _TD(r.toStringAsFixed(1)),
                        _TD(_intensity(r)),
                      ]);
                    }),
                  ],
                ),
              ),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String icon, label, value;
  final Color  color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  const _ToggleBtn(
      {required this.label, required this.active, required this.onTap});

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
        child: Text(label,
            style: TextStyle(
                color: active ? AppColors.accent : AppColors.textMuted,
                fontSize: 11,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }
}

Widget _TH(String t) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(t,
        style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700)));

Widget _TD(String t) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(t,
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 11)));