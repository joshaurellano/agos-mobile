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
          // ── KPI Row ─────────────────────────────────────────
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
                _StatCard(label: 'Current Level', value: '${_currentLevel}m', color: _getColor(_currentLevel), icon: '📏'),
                _StatCard(label: '24h Peak',       value: '3.4m',             color: AppColors.orange,           icon: '📈'),
                _StatCard(label: '24h Low',        value: '1.6m',             color: AppColors.green,            icon: '📉'),
                _StatCard(label: 'Rate of Rise',   value: '+0.12m/hr',        color: AppColors.yellow,           icon: '⚡'),
              ],
            );
          }),
          const SizedBox(height: 16),

          // ── Gauge + Legend + Chart ───────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blueCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.blueBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💧 Water Level Gauge — Bicol River (Triangulo Station)',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Gauge + legend (wraps on very small screens)
                Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    // Vertical gauge
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('LEVEL',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        Container(
                          width: 50,
                          height: 180,
                          decoration: BoxDecoration(
                            color: AppColors.blueMid,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.blueBorder, width: 2),
                          ),
                          child: Stack(children: [
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 180 * (_currentLevel / 6),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    colors: [
                                      _getColor(_currentLevel),
                                      _getColor(_currentLevel)
                                          .withOpacity(0.5),
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 180 * (3.5 / 6),
                              left: 0,
                              right: 0,
                              child: Container(
                                  height: 2,
                                  color: AppColors.orange.withOpacity(0.7)),
                            ),
                            Positioned(
                              bottom: 180 * (4.5 / 6),
                              left: 0,
                              right: 0,
                              child: Container(
                                  height: 2,
                                  color: AppColors.red.withOpacity(0.7)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_currentLevel}m',
                          style: TextStyle(
                            color: _getColor(_currentLevel),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),

                    // Legend
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: r['color'] as Color),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                r['level'] as String,
                                style: TextStyle(
                                    color: r['color'] as Color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              Text(r['label'] as String,
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11)),
                            ]),
                          ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.blueMid,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Status',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getStatus(_currentLevel),
                                style: TextStyle(
                                  color: _getColor(_currentLevel),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Source: PAGASA Bicol River\nBasin Data + DOST-ASTI Sensor',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Chart / Table toggle
                Row(children: [
                  _ToggleBtn(
                      label: '📈 Chart',
                      active: !_showTable,
                      onTap: () => setState(() => _showTable = false)),
                  const SizedBox(width: 8),
                  _ToggleBtn(
                      label: '📋 Table',
                      active: _showTable,
                      onTap: () => setState(() => _showTable = true)),
                ]),
                const SizedBox(height: 12),

                if (!_showTable)
                  SizedBox(
                    height: 220,
                    child: LineChart(LineChartData(
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
                          getTitlesWidget: (v, _) => Text('${v.toInt()}m',
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
                              _data[i]['hour'] as String? ?? '',
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
                      lineBarsData: [
                        LineChartBarData(
                          spots: _data.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(),
                                (e.value['level'] as double));
                          }).toList(),
                          isCurved: true,
                          color: AppColors.accent,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.accent.withOpacity(0.08),
                          ),
                        ),
                      ],
                    )),
                  )
                else
                  _DataTable(data: _data, xKey: 'hour', valueKey: 'level', unit: 'm'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String icon, label, value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
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
          Text(
            label.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8),
            overflow: TextOverflow.ellipsis,
          ),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                color:
                    active ? AppColors.accent : AppColors.textMuted,
                fontSize: 12,
                fontWeight: active
                    ? FontWeight.w700
                    : FontWeight.w400)),
      ),
    );
  }
}

class _DataTable extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String xKey, valueKey, unit;

  const _DataTable({
    required this.data,
    required this.xKey,
    required this.valueKey,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Table(
        border: TableBorder.all(color: AppColors.blueBorder, width: 1),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.blueMid),
            children: [
              _TH('Time'),
              _TH('Level ($unit)'),
            ],
          ),
          ...data.take(24).map((row) => TableRow(children: [
                _TD(row[xKey]?.toString() ?? ''),
                _TD('${row[valueKey]}$unit'),
              ])),
        ],
      ),
    );
  }
}

Widget _TH(String text) => Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );

Widget _TD(String text) => Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 11)),
    );