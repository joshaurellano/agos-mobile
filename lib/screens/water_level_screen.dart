import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import '../services/mock_data_service.dart';

class WaterLevelScreen extends StatefulWidget {
  const WaterLevelScreen({super.key});

  @override
  State<WaterLevelScreen> createState() => _WaterLevelScreenState();
}

class _WaterLevelScreenState extends State<WaterLevelScreen> {
  final double _currentLevel = 3.4;
  bool _showTable = false;
  late List<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _data = MockDataService.generateWaterLevelData();
  }

  Color _getColor(double level) {
    if (level >= 4.5) return AppColors.red;
    if (level >= 3.5) return AppColors.orange;
    if (level >= 2.5) return AppColors.yellow;
    return AppColors.green;
  }

  String _getStatus(double level) {
    if (level >= 4.5) return 'Critical';
    if (level >= 3.5) return 'Warning';
    if (level >= 2.5) return 'Advisory';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── KPI Row ──────────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            childAspectRatio: 1.4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _StatCard(label: 'Current Level', value: '${_currentLevel}m', color: _getColor(_currentLevel), icon: '📏'),
              _StatCard(label: '24h Peak',       value: '3.4m', color: AppColors.orange, icon: '📈'),
              _StatCard(label: '24h Low',        value: '1.6m', color: AppColors.green,  icon: '📉'),
              _StatCard(label: 'Rate of Rise',   value: '+0.12m/hr', color: AppColors.yellow, icon: '⚡'),
            ],
          ),
          const SizedBox(height: 16),

          // ── Gauge + Chart ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blueCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.blueBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('💧 Water Level Gauge — Bicol River (Triangulo Station)',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Vertical gauge
                Column(children: [
                  const Text('LEVEL', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Container(
                    width: 50, height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.blueMid,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.blueBorder, width: 2),
                    ),
                    child: Stack(children: [
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        height: 180 * (_currentLevel / 6),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              colors: [_getColor(_currentLevel), _getColor(_currentLevel).withOpacity(0.5)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ),
                      // Warning line at 3.5m
                      Positioned(
                        bottom: 180 * (3.5 / 6),
                        left: 0, right: 0,
                        child: Container(height: 2, color: AppColors.orange.withOpacity(0.7)),
                      ),
                      // Critical line at 4.5m
                      Positioned(
                        bottom: 180 * (4.5 / 6),
                        left: 0, right: 0,
                        child: Container(height: 2, color: AppColors.red.withOpacity(0.7)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text('${_currentLevel}m',
                      style: TextStyle(color: _getColor(_currentLevel), fontSize: 18, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(width: 20),

                // Legend
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final r in [
                      {'level': '≥ 4.5m',   'label': 'Critical', 'color': AppColors.red},
                      {'level': '3.5–4.4m', 'label': 'Warning',  'color': AppColors.orange},
                      {'level': '2.5–3.4m', 'label': 'Advisory', 'color': AppColors.yellow},
                      {'level': '< 2.5m',   'label': 'Normal',   'color': AppColors.green},
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: r['color'] as Color),
                          ),
                          const SizedBox(width: 8),
                          Text(r['level'] as String,
                              style: TextStyle(color: r['color'] as Color, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.3)),
                          const SizedBox(width: 8),
                          Text(r['label'] as String,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ]),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.blueMid,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Source: PAGASA Bicol River\nBasin Data + DOST-ASTI Sensor',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),

              // Toggle
              Row(children: [
                _ToggleButton(label: '📈 Chart', active: !_showTable, onTap: () => setState(() => _showTable = false)),
                const SizedBox(width: 8),
                _ToggleButton(label: '📋 Table', active: _showTable, onTap: () => setState(() => _showTable = true)),
              ]),
              const SizedBox(height: 12),

              if (!_showTable)
                SizedBox(
                  height: 180,
                  child: LineChart(LineChartData(
                    minY: 0, maxY: 6,
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (_) => FlLine(color: AppColors.blueBorder, strokeWidth: 1),
                      getDrawingVerticalLine: (_) => FlLine(color: AppColors.blueBorder, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 30,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}m',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                      )),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, interval: 5,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= _data.length) return const SizedBox();
                          return Text(_data[i]['time'] ?? '',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 8));
                        },
                      )),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    extraLinesData: ExtraLinesData(horizontalLines: [
                      HorizontalLine(y: 3.5, color: AppColors.orange, strokeWidth: 1.5, dashArray: [4, 2]),
                      HorizontalLine(y: 4.5, color: AppColors.red,    strokeWidth: 1.5, dashArray: [4, 2]),
                    ]),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _data.asMap().entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value['level'] as double))
                            .toList(),
                        isCurved: true,
                        color: AppColors.accent,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [AppColors.accent.withOpacity(0.3), AppColors.accent.withOpacity(0)],
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  )),
                )
              else
                SingleChildScrollView(
                  child: Table(
                    columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2)},
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.blueBorder))),
                        children: ['Time', 'Level (m)', 'Status'].map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Text(h, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        )).toList(),
                      ),
                      ..._data.reversed.take(12).map((row) {
                        final level = row['level'] as double;
                        final c = _getColor(level);
                        return TableRow(
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.blueBorder, width: 0.3))),
                          children: [
                            Padding(padding: const EdgeInsets.all(8),
                                child: Text(row['time'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8),
                                child: Text('${level}m', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8),
                                child: Text(_getStatus(level), style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600))),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.blueCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.blueBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 6),
      Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
    ]),
  );
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.blueMid,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? AppColors.accent : AppColors.blueBorder),
      ),
      child: Text(label, style: TextStyle(color: active ? AppColors.blueDark : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}