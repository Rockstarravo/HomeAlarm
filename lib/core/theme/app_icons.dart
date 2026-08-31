import 'package:flutter/material.dart';

/// Every icon the app uses, named by what it *means* rather than which
/// Material glyph draws it. Swapping the whole icon set — or replacing
/// Material Icons with a custom font later — is a one-file change instead
/// of a project-wide search-and-replace.
class AppIcons {
  const AppIcons._();

  // Reminders
  static const reminderActive = Icons.alarm_on;
  static const reminderInactive = Icons.alarm_off;
  static const reminderDefault = Icons.alarm;
  static const add = Icons.add;
  static const time = Icons.access_time;

  // Navigation / chrome
  static const chevronForward = Icons.chevron_right;
  static const logout = Icons.logout;
  static const testAlarm = Icons.notifications_active_outlined;
  static const myReminders = Icons.list_alt;
  static const manageReminders = Icons.edit_calendar;
  static const offline = Icons.wifi_off;

  // Onboarding permission steps
  static const notificationsPermission = Icons.notifications_active;
  static const exactAlarmPermission = Icons.alarm;
  static const batteryPermission = Icons.battery_charging_full;
  static const devicePermission = Icons.phone_android;
}
