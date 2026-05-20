import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/notification_log.dart';
import '../services/auth_service.dart';
import '../services/mock_data_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late List<NotificationLog> _logs;
  String _filter = 'ALL';

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
    _logs = MockDataService.getNotificationLog();
  }

  List<NotificationLog> get _filtered =>
      _filter == 'ALL' ? _logs : _logs.where((l) => l.typeLabel == _filter).toList();

  int get _unread => _logs.where((l) => !l.read).length;

  void _sendManualAlert(BuildContext context) {
    String selectedType = 'INFO';
    final msgCtrl = TextEditingController();
    final user = context.read<AuthService>().currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blueDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.blueBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('📢 Send Alert to Residents',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('This alert will appear in all residents\' inboxes immediately.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 20),

              // Type selector
              const Text('ALERT TYPE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: ['INFO', 'ADVISORY', 'WARNING', 'CRITICAL'].map((t) {
                  final colors = {
                    'INFO': AppColors.accent,
                    'ADVISORY': AppColors.yellow,
                    'WARNING': AppColors.orange,
                    'CRITICAL': AppColors.red,
                  };
                  final c = colors[t]!;
                  final selected = selectedType == t;
                  return GestureDetector(
                    onTap: () => setD(() => selectedType = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? c.withOpacity(0.2) : AppColors.blueMid,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? c : AppColors.blueBorder, width: selected ? 1.5 : 1),
                      ),
                      child: Text(t, style: TextStyle(
                        color: selected ? c : AppColors.textSecondary,
                        fontSize: 12, fontWeight: FontWeight.w700,
                      )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Message field
              const Text('MESSAGE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type your alert message for residents...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.blueMid,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.blueBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.blueBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Send button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (msgCtrl.text.trim().isEmpty) return;
                    final typeMap = {
                      'CRITICAL': NotificationType.critical,
                      'WARNING':  NotificationType.warning,
                      'ADVISORY': NotificationType.advisory,
                      'INFO':     NotificationType.info,
                    };
                    final newLog = NotificationLog(
                      id: DateTime.now().millisecondsSinceEpoch,
                      time: 'Just now',
                      type: typeMap[selectedType] ?? NotificationType.info,
                      message: msgCtrl.text.trim(),
                      sentBy: user?.name ?? 'Official',
                      read: false,
                    );
                    // Add to local log
                    setState(() => _logs.insert(0, newLog));
                    // Broadcast to resident alert bus
                    AlertBus.send(NotificationLog(
                      id: newLog.id,
                      time: newLog.time,
                      type: newLog.type,
                      message: newLog.message,
                      sentBy: newLog.sentBy,
                      read: false,
                    ));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Alert sent to all residents!'),
                        backgroundColor: AppColors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.blueDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Alert Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final critical = _logs.where((l) => l.type == NotificationType.critical).length;
    final thisSession = _logs.where((l) => l.time == 'Just now').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── KPIs ──────────────────────────────────────────────
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            childAspectRatio: 1.5,
            mainAxisSpacing: 12, crossAxisSpacing: 12,
            children: [
              _KpiCard(icon: '🔔', label: 'Total', value: '${_logs.length}', color: AppColors.accent),
              _KpiCard(icon: '📬', label: 'Unread', value: '$_unread',
                  color: _unread > 0 ? AppColors.orange : AppColors.green),
              _KpiCard(icon: '🔴', label: 'Critical', value: '$critical', color: AppColors.red),
              _KpiCard(icon: '📤', label: 'Sent Now', value: '$thisSession', color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 16),

          // ── Send Alert Button ─────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _sendManualAlert(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.blueDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.campaign_rounded, size: 20),
              label: const Text('Send Alert to Residents',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 16),

          // ── Log Card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blueCard, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.blueBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('🔔 Alert Log',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    if (_unread > 0)
                      GestureDetector(
                        onTap: () => setState(() {
                          _logs = _logs.map((l) => NotificationLog(
                            id: l.id, time: l.time, type: l.type,
                            message: l.message, sentBy: l.sentBy, read: true,
                          )).toList();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.blueMid,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.blueBorder),
                          ),
                          child: const Text('✓ Mark all read',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['ALL', 'CRITICAL', 'WARNING', 'ADVISORY', 'INFO'].map((f) =>
                      GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _filter == f ? AppColors.accent : AppColors.blueMid,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _filter == f ? AppColors.accent : AppColors.blueBorder),
                          ),
                          child: Text(f, style: TextStyle(
                            color: _filter == f ? AppColors.blueDark : AppColors.textSecondary,
                            fontSize: 11, fontWeight: FontWeight.w600,
                          )),
                        ),
                      ),
                    ).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                if (_filtered.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No alerts found.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                    ),
                  )
                else
                  ..._filtered.map((log) {
                    final color = _typeColors[log.type] ?? AppColors.accent;
                    return GestureDetector(
                      onTap: () => setState(() => log.read = true),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: log.read ? AppColors.blueMid : color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: log.read ? AppColors.blueBorder : color.withOpacity(0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.typeIcon, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(log.message,
                                      style: TextStyle(
                                        color: log.read ? AppColors.textSecondary : AppColors.textPrimary,
                                        fontWeight: log.read ? FontWeight.w400 : FontWeight.w600,
                                        fontSize: 13, height: 1.4,
                                      )),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      Text('🕐 ${log.time}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                      Text('👤 ${log.sentBy}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(log.typeLabel,
                                            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!log.read)
                              Container(
                                width: 8, height: 8,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
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
    decoration: BoxDecoration(
      color: AppColors.blueCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.blueBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(label.toUpperCase(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    ),
  );
}