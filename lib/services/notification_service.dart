import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/supplier_order.dart';

/// Local reminders for Supplier X order & pickup dates.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<void> reschedule(SupplierOrder order) async {
    if (!_ready) return;
    await cancel(order.id);
    if (!order.reminderEnabled || !order.status.isActive) return;
    await _schedule(
      id: order.id.hashCode & 0x7fffffff,
      title: 'Sipariş zamanı: ${order.title}',
      body: 'Supplier X sipariş: ${_fmt(order.orderDate)}',
      date: _at9am(order.orderDate),
    );
    await _schedule(
      id: (order.id.hashCode & 0x7fffffff) ^ 0x100000,
      title: 'Teslim alma: ${order.title}',
      body: 'Supplier X teslim: ${_fmt(order.pickupDate)}',
      date: _at9am(order.pickupDate),
    );
  }

  Future<void> cancel(String orderId) async {
    if (!_ready) return;
    await _plugin.cancel(orderId.hashCode & 0x7fffffff);
    await _plugin.cancel((orderId.hashCode & 0x7fffffff) ^ 0x100000);
  }

  /// Not hatırlatıcısı: verilen tarih-saatte "Not hatırlatma" bildirimi.
  Future<void> scheduleNoteReminder(
      String noteId, String text, DateTime at) async {
    if (!_ready) return;
    await cancelNote(noteId);
    await _schedule(
      id: (noteId.hashCode & 0x7fffffff) ^ 0x200000,
      title: 'Not hatırlatma',
      body: text.isEmpty ? 'Kaydedilmiş notunuz var.' : text,
      date: at,
      channel: 'notes',
      channelName: 'Not Hatırlatıcıları',
    );
  }

  Future<void> cancelNote(String noteId) async {
    if (!_ready) return;
    await _plugin.cancel((noteId.hashCode & 0x7fffffff) ^ 0x200000);
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime date,
    String channel = 'orders',
    String channelName = 'Sipariş Hatırlatıcıları',
  }) async {
    final when =
        date.isAfter(DateTime.now()) ? date : DateTime.now().add(const Duration(seconds: 5));
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(channel, channelName),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Schedule failed: $e');
    }
  }

  DateTime _at9am(DateTime d) => DateTime(d.year, d.month, d.day, 9, 0);

  String _fmt(DateTime d) => '${d.day}.${d.month}.${d.year}';
}
