import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_log.dart';

class AlertRealtimeService {
  static RealtimeChannel? _channel;

  static void start() {
    final client = Supabase.instance.client;

    _channel = client
        .channel('public:alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
          print('🔔 REALTIME RECEIVED: ${payload.newRecord}');
          final row = payload.newRecord;
          final typeMap = {
            'CRITICAL': NotificationType.critical,
            'WARNING':  NotificationType.warning,
            'ADVISORY': NotificationType.advisory,
            'NORMAL':   NotificationType.normal,
            'INFO':     NotificationType.info,
          };

          final now = DateTime.now();
          final timeStr =
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

          AlertBus.send(NotificationLog(
            id:      (row['id'] as int?) ?? now.millisecondsSinceEpoch,
            time:    timeStr,
            type:    typeMap[row['type']] ?? NotificationType.info,
            message: (row['message'] as String?) ?? '',
            sentBy:  (row['sent_by'] as String?) ?? 'Official',
            read:    false,
          ));
        },
        )
        .subscribe((status, [error]) {
          print('📡 Realtime status: $status, error: $error');
        });
  }

  static void stop() {
    _channel?.unsubscribe();
    _channel = null;
  }
}