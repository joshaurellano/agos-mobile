import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_log.dart';

class AlertRealtimeService {
  static RealtimeChannel? _channel;

  static final _typeMap = {
    'CRITICAL': NotificationType.critical,
    'WARNING':  NotificationType.warning,
    'ADVISORY': NotificationType.advisory,
    'NORMAL':   NotificationType.normal,
    'INFO':     NotificationType.info,
  };

  static NotificationLog _rowToLog(Map<String, dynamic> row) {
    // Parse created_at from DB if available, else fall back to now
    DateTime ts;
    try {
      ts = DateTime.parse(row['created_at'] as String).toLocal();
    } catch (_) {
      ts = DateTime.now();
    }
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    return NotificationLog(
      id:      (row['id'] as int?) ?? ts.millisecondsSinceEpoch,
      time:    timeStr,
      type:    _typeMap[row['type']] ?? NotificationType.info,
      message: (row['message'] as String?) ?? '',
      sentBy:  (row['sent_by'] as String?) ?? 'Official',
      read:    false,
    );
  }

  /// Call once at startup. Fetches all existing alerts then subscribes
  /// to realtime inserts so new ones arrive without a refresh.
  static Future<void> start() async {
    final client = Supabase.instance.client;

    // ── 1. Initial fetch ──────────────────────────────────────
    try {
      final response = await client
          .from('alerts')
          .select()
          .order('created_at', ascending: false);

      for (final row in response as List<dynamic>) {
        final log = _rowToLog(row as Map<String, dynamic>);
        // Use loadSilent so we don't fire listeners on every row
        AlertBus.load(log);
      }
      // Notify listeners once after all rows are loaded
      AlertBus.notifyListeners();
    } catch (e) {
      print('⚠️ Failed to fetch alerts: $e');
    }

    // ── 2. Realtime subscription for new inserts ──────────────
    _channel = client
        .channel('public:alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
            print('🔔 REALTIME RECEIVED: ${payload.newRecord}');
            AlertBus.send(_rowToLog(payload.newRecord));
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