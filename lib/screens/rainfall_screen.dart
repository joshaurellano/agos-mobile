import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class RainfallScreen extends StatefulWidget {
  const RainfallScreen({super.key});

  @override
  State<RainfallScreen> createState() => _RainfallScreenState();
}

class _RainfallScreenState extends State<RainfallScreen> {
  bool _showTable = false;
  bool _isHourly  = true;
  bool _loading   = true;

  List<Map<String, dynamic>> _hourlyData = [];
  List<Map<String, dynamic>> _dailyData  = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;

      // ── Hourly: last 24 hours ─────────────────────────────
      final since = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      final hourlyRes = await client
          .from('prediction_logs')
          .select('recorded_at, rainfall_mm')
          .gte('recorded_at', since)
          .order('recorded_at', ascending: true);

      final hourlyBuckets = <String, Map<String, dynamic>>{};
      for (final row in hourlyRes as List) {
        final dt   = DateTime.parse(row['recorded_at'] as String).toLocal();
        final hour = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        hourlyBuckets.putIfAbsent(hour, () => {'hour': hour, 'rainfall': 0.0});
        hourlyBuckets[hour]!['rainfall'] =
            (hourlyBuckets[hour]!['rainfall'] as double) +
            (row['rainfall_mm'] as num).toDouble();
      }

      // ── Daily: last 7 days ────────────────────────────────
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();
      final dailyRes = await client
          .from('prediction_logs')
          .select('recorded_at, rainfall_mm')
          .gte('recorded_at', sevenDaysAgo)
          .order('recorded_at', ascending: true);

      final dailyBuckets = <String, Map<String, dynamic>>{};
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      for (final row in dailyRes as List) {
        final dt   = DateTime.parse(row['recorded_at'] as String).toLocal();
        final date = '${months[dt.month - 1]} ${dt.day}';
        dailyBuckets.putIfAbsent(date, () => {'date': date, 'rainfall': 0.0});
        dailyBuckets[date]!['rainfall'] = double.parse(
          ((dailyBuckets[date]!['rainfall'] as double) +
                  (row['rainfall_mm'] as num).toDouble())
              .toStringAsFixed(2),
        );
      }

      setState(() {
        _hourlyData = hourlyBuckets.values.toList();
        _dailyData  = dailyBuckets.values.toList();
        _loading    = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _data => _isHourly ? _hourlyData : _dailyData;
  String get _xKey => _isHourly ? 'hour' : 'date';

  double get _total =>
      _data.fold(0.0, (s, d) => s + (d['rainfall'] as double));
  double get _peak => _data.isEmpty
      ? 0.0
      : _data.map((d) => d['rainfall'] as double).reduce((a, b) => a > b ? a : b);

  String _intensity(double r) {
    if (r >= 50) return '🔴 Heavy';
    if (r >= 25) return '🟠 Moderate';
    if (r >= 10) return '🟡 Light';
    return '🟢 Trace';
  }

  Color _barColor(double r) {
    if (r >= 50) return AppColors.red;
    if (r >= 25) return AppColors.orange;
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── KPIs ─────────────────────────────────────────────
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
              _KpiCard(
                icon: '☔',
                label: 'Total Accumulated',
                value: '${_total.toStringAsFixed(1)}mm',
                color: AppColors.accent,
              ),
              _KpiCard(
                icon: '⚡',
                label: 'Peak Intensity',
                value: '${_peak.toStringAsFixed(1)}mm/hr',
                color: AppColors.orange,
              ),
              const _KpiCard(
                icon: '⏱',
                label: '3-Hr Accumulation',
                value: '—',          // will be replaced once prediction service exists
                color: AppColors.yellow,
              ),
              const _KpiCard(
                icon: '⚠️',
                label: 'PAGASA Threshold',
                value: '50mm',
                color: AppColors.textSecondary,
              ),
            ],
          );
        }),
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
            // Toolbar
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                const Text('🌧 Rainfall Accumulation',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                _ToggleBtn(
                    label: 'Hourly',
                    active: _isHourly,
                    onTap: () => setState(() => _isHourly = true)),
                _ToggleBtn(
                    label: 'Daily',
                    active: !_isHourly,
                    onTap: () => setState(() => _isHourly = false)),
                _ToggleBtn(
                    label: '📈',
                    active: !_showTable,
                    onTap: () => setState(() => _showTable = false)),
                _ToggleBtn(
                    label: '📋',
                    active: _showTable,
                    onTap: () => setState(() => _showTable = true)),
              ],
            ),
            const SizedBox(height: 16),

            if (_loading)
              const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accent, strokeWidth: 2),
                ),
              )
            else if (_data.isEmpty)
              Container(
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.blueMid,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.blueBorder),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('📡', style: TextStyle(fontSize: 28)),
                    SizedBox(height: 10),
                    Text('No data yet',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Logs will appear once the backend starts recording.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              )
            else if (!_showTable)
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
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: 50,
                      color: AppColors.red,
                      strokeWidth: 1.5,
                      dashArray: [4, 2],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        labelResolver: (_) => 'Heavy Rain Threshold',
                        style: const TextStyle(
                            color: AppColors.red, fontSize: 9),
                      ),
                    ),
                    if (!_isHourly)
                      HorizontalLine(
                        y: 18.5,
                        color: AppColors.yellow,
                        strokeWidth: 1,
                        dashArray: [3, 3],
                      ),
                  ]),
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
                    final r = e.value['rainfall'] as double;
                    return BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(
                        toY: r,
                        color: _barColor(r),
                        width: _isHourly ? 6 : 16,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ]);
                  }).toList(),
                )),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  border:
                      TableBorder.all(color: AppColors.blueBorder, width: 1),
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(
                      decoration:
                          const BoxDecoration(color: AppColors.blueMid),
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
                        _TD('${r.toStringAsFixed(1)}mm'),
                        _TD(_intensity(r)),
                      ]);
                    }),
                  ],
                ),
              ),
          ]),
        ),

        // ── Legend ────────────────────────────────────────────
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.blueCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.blueBorder),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final r in [
                {'label': '🟢 Trace',        'range': '< 10mm/hr',  'color': AppColors.green},
                {'label': '🟡 Light Rain',    'range': '10–25mm/hr', 'color': AppColors.yellow},
                {'label': '🟠 Moderate Rain', 'range': '25–50mm/hr', 'color': AppColors.orange},
                {'label': '🔴 Heavy Rain',    'range': '≥ 50mm/hr',  'color': AppColors.red},
              ])
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(r['label'] as String,
                      style: TextStyle(
                          color: r['color'] as Color, fontSize: 12)),
                  const SizedBox(width: 4),
                  Text('(${r['range']})',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ]),
              const Text(
                'Source: PAGASA Weather Station · Naga City',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.blueCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blueBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
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
  final String       label;
  final bool         active;
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
    child:
        Text(t, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11)));