import 'package:flutter/material.dart';
import '../main.dart';

class WaterLevelScreen extends StatefulWidget {
  const WaterLevelScreen({super.key});

  @override
  State<WaterLevelScreen> createState() => _WaterLevelScreenState();
}

class _WaterLevelScreenState extends State<WaterLevelScreen> {
  bool _showTable = false;

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
              children: const [
                _StatCard(label: 'Current Level', value: 'N/A', icon: '📏', noData: true),
                _StatCard(label: '24h Peak',       value: 'N/A', icon: '📈', noData: true),
                _StatCard(label: '24h Low',        value: 'N/A', icon: '📉', noData: true),
                _StatCard(label: 'Rate of Rise',   value: 'N/A', icon: '⚡', noData: true),
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

                // Gauge + legend
                Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    // Vertical gauge — no data state
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
                            // Threshold lines (dimmed, for reference)
                            Positioned(
                              bottom: 180 * (3.5 / 6),
                              left: 0,
                              right: 0,
                              child: Container(
                                  height: 2,
                                  color: AppColors.orange.withOpacity(0.4)),
                            ),
                            Positioned(
                              bottom: 180 * (4.5 / 6),
                              left: 0,
                              right: 0,
                              child: Container(
                                  height: 2,
                                  color: AppColors.red.withOpacity(0.4)),
                            ),
                            // No data label
                            const Center(
                              child: Text(
                                'No\nData',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    height: 1.4),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '— m',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
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
                          child: const Text(
                            'Source: PAGASA Bicol River\nBasin Data + DOST-ASTI Sensor',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
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

                // No sensor data placeholder (same for both chart and table views)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.blueMid,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.blueBorder,
                        style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📡',
                          style: TextStyle(fontSize: 28, color: AppColors.textMuted)),
                      SizedBox(height: 10),
                      Text(
                        'No sensor data available',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Live readings will appear here once the sensor is connected',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
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
  final bool noData;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.noData = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: noData ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(10), // was 12
        decoration: BoxDecoration(
          color: AppColors.blueCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.blueBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)), // was 18
            const SizedBox(height: 2), // was 4
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
            FittedBox( // wrap in FittedBox so it scales down if needed
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 20,
                    fontWeight: FontWeight.w900),
              ),
            ),
            if (noData) ...[
              const SizedBox(height: 2), // was 4
              Row(children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.textMuted),
                ),
                const SizedBox(width: 4),
                const Text(
                  'No sensor data',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 9),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }
}