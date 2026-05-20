import 'package:flutter/material.dart';
import '../main.dart';
import '../models/notification_log.dart';

class ResidentAlertsScreen extends StatefulWidget {
  const ResidentAlertsScreen({super.key});

  @override
  State<ResidentAlertsScreen> createState() => _ResidentAlertsScreenState();
}

class _ResidentAlertsScreenState extends State<ResidentAlertsScreen> {
  List<NotificationLog> _alerts = [];

  static const _typeColors = {
    NotificationType.critical: AppColors.red,
    NotificationType.warning:  AppColors.orange,
    NotificationType.advisory: AppColors.yellow,
    NotificationType.normal:   AppColors.green,
    NotificationType.info:     AppColors.accent,
  };

  @override
  void initState() {
    super.initState();
    _refresh();
    AlertBus.addListener(_refresh);
  }

  @override
  void dispose() {
    AlertBus.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _alerts = List.from(AlertBus.alerts));
  }

  int get _unread => _alerts.where((a) => !a.read).length;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────
          Row(
            children: [
              const Text('🔔 My Alerts',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (_unread > 0)
                GestureDetector(
                  onTap: () => setState(() {
                    for (final a in _alerts) a.read = true;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.blueMid,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.blueBorder),
                    ),
                    child: Text('✓ Mark all read ($_unread)',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Empty state ───────────────────────────────────────
          if (_alerts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: AppColors.blueCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.blueBorder),
              ),
              child: const Column(
                children: [
                  Text('🔕', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text('No alerts yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('You\'ll be notified when barangay officials\nsend flood alerts.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ..._alerts.map((alert) {
              final color = _typeColors[alert.type] ?? AppColors.accent;
              return GestureDetector(
                onTap: () => setState(() => alert.read = true),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: alert.read ? AppColors.blueCard : color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: alert.read ? AppColors.blueBorder : color.withOpacity(0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type icon with colored circle
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withOpacity(0.15),
                        ),
                        child: Center(
                          child: Text(alert.typeIcon, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(alert.typeLabel,
                                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                                ),
                                const Spacer(),
                                Text(alert.time,
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(alert.message,
                                style: TextStyle(
                                  color: alert.read ? AppColors.textSecondary : AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: alert.read ? FontWeight.w400 : FontWeight.w600,
                                  height: 1.45,
                                )),
                            const SizedBox(height: 5),
                            Text('Sent by ${alert.sentBy}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (!alert.read)
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(top: 4, left: 6),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}