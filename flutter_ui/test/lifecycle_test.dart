import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telexmini_ui/src/app.dart';
import 'package:telexmini_ui/src/controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('com.telexmini/control');

  testWidgets('closing settings asks Flutter UI to exit, leaving the tray engine',
      (tester) async {
    final temp = Directory.systemTemp.createTempSync('telexmini-lowmem-');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
      calls.add(call.method);
      if (call.method == 'getStatus') {
        return <String, dynamic>{'vietnameseEnabled': true,
            'automaticMode': true};
      }
      if (call.method == 'loadDictionary') return <String>[];
      if (call.method == 'loadProfiles') return '';
      return null;
    });
    final c = AppController(settingsDirectoryOverride: temp.path);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    try {
      await tester.runAsync(() => c.load());
      await tester.pumpWidget(TelexMiniApp(controller: c));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.byTooltip('Đóng giao diện · bộ gõ vẫn chạy'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, contains('closeUi'));
      expect(find.byType(MaterialApp), findsOneWidget);
    } finally {
      c.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(native, null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.pumpWidget(const SizedBox.shrink());
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    }
  });
}
