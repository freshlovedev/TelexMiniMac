import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telexmini_ui/src/controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.telexmini/control');

  test('Windows preferences notification refreshes V/E without 180ms polling',
      () async {
    if (!Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp('telexmini-watch-');
    bool nativeVietnamese = true;
    int bridgeCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getStatus') {
        bridgeCalls++;
        return {'vietnameseEnabled': nativeVietnamese, 'automaticMode': true};
      }
      if (call.method == 'loadDictionary') return <String>[];
      if (call.method == 'loadProfiles') return '';
      return null;
    });
    final controller = AppController(settingsDirectoryOverride: directory.path);
    try {
      await controller.load();
      expect(controller.vietnameseEnabled, true);
      controller.startNativeMonitoring();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final baselineCalls = bridgeCalls;
      expect(baselineCalls, 1);
      nativeVietnamese = false;
      await File('${directory.path}/preferences.ini').writeAsString(
          'VietnameseEnabled=false\n', flush: true);
      for (var i = 0; i < 20 && controller.vietnameseEnabled; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 75));
      }
      expect(controller.vietnameseEnabled, false,
          reason: 'File notification should update UI well before fallback poll');
      expect(bridgeCalls, greaterThan(baselineCalls));
    } finally {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}
