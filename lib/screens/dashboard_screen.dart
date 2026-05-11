import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/alert_level.dart';
import '../models/data_source.dart';
import '../services/auth_service.dart';
import '../services/mock_data_service.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<AlertLevelType>? onAlertChanged;
  const DashboardScreen({super.key, this.onAlertChanged});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AlertLevelType _alertLevel = AlertLevelType.warning;
  double _currentLevel = 3.4;
  List<Map<String, dynamic>> _waterData = [];
  DateTime _lastUpdate = DateTime.now();
  Timer? _timer;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _waterData = MockDataService.generateWaterLevelData();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _updateData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateData() {
    if (!mounted) return;
    setState(() {
      final last = _waterData.last['level'] as double;
      final newLevel = (last + (_rng.nextDouble() - 0.45) * 0.15).clamp(0.5, 6.0);
      _currentLevel = double.parse(newLevel.toStringAsFixed(2));
      _alertLevel = AlertLevel.fromWaterLevel(_currentLevel);
      widget.onAlertChanged?.call(_alertLevel);
      _lastUpdate = DateTime.now();
      final now = DateTime.now();
      _waterData = [
        ..._waterData.sublist(1),
        {
          'time': '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
          'level': _currentLevel,
        }
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isResident = user?.isResident ?? false;
    final alertInfo = AlertLevel.levels[_alertLevel]!;
    final liveCount = MockDataService.dataSources
        .where((s) => s.status == SourceStatus.live).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Alert Banner ─────────────────────────────────────
          _AlertBanner(alertInfo: alertInfo, currentLevel: _currentLevel),
          const SizedBox(height: 16),

          // ── KPI Row ──────────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            childAspectRatio: 1.4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _StatCard(
                icon: '💧', label: 'Current Water Level',
                value: '${_currentLevel}m', sub: 'Bicol River Station',
                color: _currentLevel >= 3.5 ? AppColors.orange : AppColors.green,
              ),
              _StatCard(
                icon: '🌧', label: 'Rainfall (Last 3hr)',
                value: '45.1mm', sub: 'PAGASA Station',
                color: AppColors.accent,
              ),
              _StatCard(
                icon: '📡', label: 'Data Sources Live',
                value: '$liveCount/${MockDataService.dataSources.length}',
                sub: 'Active connections', color: AppColors.green,
              ),
              _StatCard(
                icon: '🏠', label: 'Households at Risk',
                value: '156', sub: 'Zone 3 — High Risk',
                color: AppColors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Water Level Chart ─────────────────────────────────
          _WaterLevelChart(waterData: _waterData, lastUpdate: _lastUpdate),
          const SizedBox(height: 16),

          // ── Bottom Row ────────────────────────────────────────
          LayoutBuilder(builder: (_, constraints) {
            final wide = constraints.maxWidth > 600;
            return Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(flex: wide ? 1 : 0, child: _WeatherForecastCard()),
                SizedBox(width: wide ? 12 : 0, height: wide ? 0 : 12),
                Flexible(flex: wide ? 1 : 0,
                    child: _AlertLevelsCard(currentLevel: _alertLevel)),
              ],
            );
          }),
          const SizedBox(height: 16),

          // ── Evacuation Button ─────────────────────────────────
          if (!isResident) _EvacuationButton(),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final AlertLevel alertInfo;
  final double currentLevel;
  const _AlertBanner({required this.alertInfo, required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Container(width: 4, color: alertInfo.color),
          Expanded(
            
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: alertInfo.color.withOpacity(0.08),
                border: Border.all(color: alertInfo.color.withOpacity(0.3)), // ← uniform
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: alertInfo.color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${alertInfo.label.toUpperCase()} LEVEL',
                          style: TextStyle(
                            color: alertInfo.color, fontWeight: FontWeight.w800,
                            fontSize: 14, letterSpacing: 1,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(alertInfo.description,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('🔔 ${alertInfo.action}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: alertInfo.color.withOpacity(0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('STATUS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    const Text('⚠️ Flooding possible\nin the next 6 hrs in Zone 3',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon, label, value, sub;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blueBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(label.toUpperCase(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
    );
  }
}

class _WaterLevelChart extends StatelessWidget {
  final List<Map<String, dynamic>> waterData;
  final DateTime lastUpdate;
  const _WaterLevelChart({required this.waterData, required this.lastUpdate});

  @override
  Widget build(BuildContext context) {
    final spots = waterData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value['level'] as double)))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blueCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blueBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('💧 Real-Time Water Level Gauge',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          Text(
            'Updated: ${lastUpdate.hour.toString().padLeft(2,"0")}:${lastUpdate.minute.toString().padLeft(2,"0")}:${lastUpdate.second.toString().padLeft(2,"0")}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(width: 16, height: 3, color: AppColors.orange),
          const SizedBox(width: 6),
          const Text('Warning (3.5m)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(width: 16),
          Container(width: 16, height: 3, color: AppColors.red),
          const SizedBox(width: 6),
          const Text('Critical (4.5m)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0, maxY: 6,
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (_) => FlLine(color: AppColors.blueBorder, strokeWidth: 1),
                getDrawingVerticalLine: (_) => FlLine(color: AppColors.blueBorder, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}m',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 4,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= waterData.length) return const SizedBox();
                      return Text(waterData[i]['time'] ?? '',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 8));
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              extraLinesData: ExtraLinesData(horizontalLines: [
                HorizontalLine(y: 3.5, color: AppColors.orange, strokeWidth: 2, dashArray: [4, 2]),
                HorizontalLine(y: 4.5, color: AppColors.red,    strokeWidth: 2, dashArray: [4, 2]),
              ]),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.accent,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [AppColors.accent.withOpacity(0.3), AppColors.accent.withOpacity(0.02)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _WeatherForecastCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blueCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blueBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('⛅ Weather Forecast Strip — Next 72 Hours',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: MockDataService.weatherForecast.map((f) => Container(
              width: 80,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.blueMid,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.blueBorder),
              ),
              child: Column(children: [
                Text(f.time, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(f.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text(f.temp, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${f.rainChance}% 🌧', style: const TextStyle(color: AppColors.accent, fontSize: 10)),
                Text(f.wind, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
              ]),
            )).toList(),
          ),
        ),
      ]),
    );
  }
}

class _AlertLevelsCard extends StatelessWidget {
  final AlertLevelType currentLevel;
  const _AlertLevelsCard({required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blueCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blueBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🚦 Flood Risk Alert Levels',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 12),
        ...AlertLevel.levels.entries.map((entry) {
          final isCurrent = entry.key == currentLevel;
          final info = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrent ? info.color.withOpacity(0.1) : AppColors.blueMid,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent ? info.color.withOpacity(0.5) : AppColors.blueBorder,
              ),
            ),
            child: Row(children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: info.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info.label.toUpperCase(),
                      style: TextStyle(color: info.color, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
                  Text(info.description.split('.')[0],
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ]),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: info.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('CURRENT',
                      style: TextStyle(color: info.color, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
            ]),
          );
        }),
      ]),
    );
  }
}

class _EvacuationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withOpacity(0.2)),
      ),
      child: Column(children: [
        const Text('EMERGENCY ACTION',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _showEvacuationDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('🚨  Send One-Click Evacuation Alert',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Notifies all registered officials and residents in Barangay Triangulo',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }

  void _showEvacuationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.blueDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('⚠️ Send Evacuation Alert?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'This will send an evacuation alert to all registered officials and residents in Barangay Triangulo.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.blueMid,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '📢 "Flooding possible in the next 6 hours in Zone 3. Please proceed to designated evacuation centers immediately."',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Evacuation alert dispatched to all officials and residents.'),
                  backgroundColor: AppColors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('🚨 Send Alert Now'),
          ),
        ],
      ),
    );
  }
}