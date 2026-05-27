import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kForegroundNotification = 'foreground_notification_enabled';

class ForegroundNotificationNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kForegroundNotification) ?? false;
  }

  Future<void> toggle() async {
    final newValue = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kForegroundNotification, newValue);
    state = newValue;
  }
}

final foregroundNotificationProvider =
    NotifierProvider<ForegroundNotificationNotifier, bool>(
  ForegroundNotificationNotifier.new,
);
