import 'package:flutter/services.dart';

import '../models/android_app_info.dart';

class AndroidAppService {
  static const MethodChannel _channel = MethodChannel('full_cleaner/android');

  Future<List<AndroidAppInfo>> getInstalledApps() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('listApps') ?? <dynamic>[];
    final apps = raw
        .whereType<Map<dynamic, dynamic>>()
        .map(AndroidAppInfo.fromMap)
        .where((app) => app.packageName.isNotEmpty)
        .toList();

    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return apps;
  }

  Future<void> openSettings(String packageName) async {
    await _channel.invokeMethod<void>(
      'openSettings',
      <String, Object?>{'packageName': packageName},
    );
  }

  Future<bool> uninstall(String packageName) async {
    return await _channel.invokeMethod<bool>(
          'uninstall',
          <String, Object?>{'packageName': packageName},
        ) ??
        false;
  }
}
