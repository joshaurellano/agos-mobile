enum NotificationType { critical, warning, advisory, normal, info }

class NotificationLog {
  final int id;
  final String time;
  final NotificationType type;
  final String message;
  final String sentBy;
  bool read;

  NotificationLog({
    required this.id,
    required this.time,
    required this.type,
    required this.message,
    required this.sentBy,
    required this.read,
  });

  String get typeLabel {
    switch (type) {
      case NotificationType.critical: return 'CRITICAL';
      case NotificationType.warning:  return 'WARNING';
      case NotificationType.advisory: return 'ADVISORY';
      case NotificationType.normal:   return 'NORMAL';
      case NotificationType.info:     return 'INFO';
    }
  }

  String get typeIcon {
    switch (type) {
      case NotificationType.critical: return '🔴';
      case NotificationType.warning:  return '🟠';
      case NotificationType.advisory: return '🟡';
      case NotificationType.normal:   return '🟢';
      case NotificationType.info:     return '🔵';
    }
  }
}

// Shared in-memory alert bus so sent alerts appear in resident inbox
class AlertBus {
  static final List<NotificationLog> _alerts = [];
  static final List<void Function()> _listeners = [];

  static List<NotificationLog> get alerts => List.unmodifiable(_alerts);

  static void send(NotificationLog log) {
    _alerts.insert(0, log);
    for (final l in _listeners) l();
  }

  static void addListener(void Function() fn) => _listeners.add(fn);
  static void removeListener(void Function() fn) => _listeners.remove(fn);
}