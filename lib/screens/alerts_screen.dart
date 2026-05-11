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

  static final _typeColors = {
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

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.blueDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('📢 Send Manual Alert',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(alignment: Alignment.centerLeft,
                child: Text('ALERT TYPE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.8))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              dropdownColor: AppColors.blueMid,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                filled: true, fillColor: AppColors.blueMid,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.blueBorder)),
              ),
              items: ['INFO', 'ADVISORY', 'WARNING', 'CRITICAL']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setD(() => selectedType = v!),
            ),
            const SizedBox(height: 14),
            const Align(alignment: Alignment.centerLeft,
                child: Text('MESSAGE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.8))),
            const SizedBox(height: 6),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter your alert message...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true, fillColor: AppColors.blueMid,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.blueBorder)),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
            ElevatedButton(
              onPressed: () {
                if (msgCtrl.text.trim().isEmpty) return;
                final typeMap = {
                  'CRITICAL': NotificationType.critical,
                  'WARNING':  NotificationType.warning,
                  'ADVISORY': NotificationType.advisory,
                  'INFO':     NotificationType.info,
                };
                setState(() {
                  _logs.insert(0, NotificationLog(
                    id: DateTime.now().millisecondsSinceEpoch,
                    time: 'Just now',
                    type: typeMap[selectedType] ?? NotificationType.info,
                    message: msgCtrl.text.trim(),
                    sentBy: 'Manual (Admin)',
                    read: true,
                  ));
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Alert sent!'), backgroundColor: AppColors.green),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.blueDark),
              child: const Text('📨 Send Alert'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isResident = user?.isResident ?? false;
    final critical = _logs.where((l) => l.type == NotificationType.critical).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── KPIs ─────────────────────────────────────────────
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
          childAspectRatio: 1.4, mainAxisSpacing: 12, crossAxisSpacing: 12,
          children: [
            _KpiCard(icon: '🔔', label: 'Total Alerts', value: '${_logs.length}', color: AppColors.accent),
            _KpiCard(icon: '📬', label: 'Unread', value: '$_unread', color: _unread > 0 ? AppColors.orange : AppColors.green),
            _KpiCard(icon: '🔴', label: 'Critical Sent', value: '$critical', color: AppColors.red),
            _KpiCard(icon: '📤', label: 'This Session', value: '${_logs.where((l) => l.time == "Just now").length}', color: AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: 16),

        // ── Log Card ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.blueCard, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.blueBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🔔 Notification Log',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              if (_unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.orange.withOpacity(0.3)),
                  ),
                  child: Text('$_unread unread',
                      style: const TextStyle(color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                ...['ALL', 'CRITICAL', 'WARNING', 'ADVISORY', 'INFO'].map((f) => GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                )),
                GestureDetector(
                  onTap: () => setState(() => _logs = _logs.map((l) => NotificationLog(id: l.id, time: l.time, type: l.type, message: l.message, sentBy: l.sentBy, read: true)).toList()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.blueMid, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.blueBorder)),
                    child: const Text('✓ Mark All Read', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (!isResident)
                  GestureDetector(
                    onTap: () => _sendManualAlert(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                      child: const Text('+ Send Alert', style: TextStyle(color: AppColors.blueDark, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            if (_filtered.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No alerts found.', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
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
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(log.typeIcon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(log.message,
                              style: TextStyle(
                                color: log.read ? AppColors.textSecondary : AppColors.textPrimary,
                                fontWeight: log.read ? FontWeight.w400 : FontWeight.w600,
                                fontSize: 13, height: 1.4,
                              )),
                          const SizedBox(height: 5),
                          Row(children: [
                            Text('🕐 ${log.time}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            const SizedBox(width: 10),
                            Text('👤 ${log.sentBy}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(log.typeLabel, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                          ]),
                        ]),
                      ),
                      if (!log.read)
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                        ),
                    ]),
                  ),
                );
              }),
            const SizedBox(height: 8),
            const Text(
              '📝 Logs are stored locally per session. In production, this would be saved to a database.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
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