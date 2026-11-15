import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telexmini_ui/src/app.dart';
import 'package:telexmini_ui/src/controller.dart';
import 'package:telexmini_ui/src/widgets.dart';

const _bridge = MethodChannel('com.telexmini/control');

void _installMockBridge(List<MethodCall> calls) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_bridge, (call) async {
    calls.add(call);
    switch (call.method) {
      case 'getStatus':
        return <String, dynamic>{
          'vietnameseEnabled': true,
          'automaticMode': true,
        };
      case 'loadDictionary':
        return <String>[];
      default:
        return null;
    }
  });
}

void _removeMockBridge() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_bridge, null);
}

AppController makeIsolatedController() {
  final folder = Directory.systemTemp.createTempSync('telexmini-widget-test-');
  addTearDown(() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        if (await folder.exists()) await folder.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    // A slow antivirus or an in-flight asynchronous write may retain a
    // handle temporarily. Keep tests isolated rather than touching user data.
  });
  return AppController(settingsDirectoryOverride: folder.path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shared desktop shell renders brand and overview', (tester) async {
    final controller = makeIsolatedController();
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() => controller.load());
    await tester.pumpWidget(TelexMiniApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('telexmini'), findsOneWidget);
    expect(find.text('Gõ theo cách của bạn.'), findsOneWidget);
    expect(find.text('TÙY CHỈNH TRẢI NGHIỆM'), findsOneWidget);
    expect(find.text('THỬ GÕ NGAY'), findsOneWidget);
    expect(find.text('Từ điển Anh'), findsOneWidget);
  });

  testWidgets('1080x680 desktop layout has no overflow and uses custom icon', (tester) async {
    final controller = makeIsolatedController();
    tester.view.physicalSize = const Size(1080, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() => controller.load());
    await tester.pumpWidget(TelexMiniApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('T'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact layout exposes responsive navigation', (tester) async {
    final controller = makeIsolatedController();
    tester.view.physicalSize = const Size(760, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() => controller.load());
    await tester.pumpWidget(TelexMiniApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('V/E mode switch updates UI and native bridge', (tester) async {
    final calls = <MethodCall>[];
    _installMockBridge(calls);
    addTearDown(_removeMockBridge);
    final controller = makeIsolatedController();
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() => controller.load());
    await tester.pumpWidget(TelexMiniApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('TIẾNG VIỆT'), findsOneWidget);
    await tester.tap(find.textContaining('TIẾNG VIỆT'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(controller.vietnameseEnabled, isFalse);
    expect(find.textContaining('TIẾNG ANH'), findsOneWidget);
    expect(calls.any((call) => call.method == 'setMode'), isTrue);
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 150)));
    expect(calls.any((call) => call.method == 'applyPreferences'), isTrue);
  });

  testWidgets('dictionary add and remove persist through native bridge', (tester) async {
    final calls = <MethodCall>[];
    _installMockBridge(calls);
    addTearDown(_removeMockBridge);
    final controller = makeIsolatedController();
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.runAsync(() => controller.load());
    await tester.pumpWidget(TelexMiniApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Từ điển Anh'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Chưa có từ tùy chỉnh'), findsOneWidget);
    await tester.tap(find.text('Thêm từ'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.byType(TextField).last, 'parameter');
    await tester.tap(find.text('Thêm').last);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('parameter'), findsOneWidget);
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 150)));
    expect(calls.any((call) => call.method == 'saveDictionary'), isTrue);

    await tester.tap(find.byTooltip('Xóa từ'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('parameter'), findsNothing);
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 150)));
    expect(calls.where((call) => call.method == 'saveDictionary').length, 2);
  });
  testWidgets('external native mode is reflected in UI', (tester) async {
    bool nativeVietnamese = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_bridge, (call) async {
        if (call.method == 'getStatus') {
          return <String, dynamic>{
            'vietnameseEnabled': nativeVietnamese,
            'automaticMode': true,
          };
        }
        if (call.method == 'loadDictionary') return <String>[];
        return null;
      });
    addTearDown(_removeMockBridge);
    final controller = makeIsolatedController();
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() => controller.load());
    await tester.pumpWidget(TelexMiniApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('TIẾNG VIỆT'), findsOneWidget);

    nativeVietnamese = false;
    await controller.refreshNativeMode();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('TIẾNG ANH'), findsOneWidget);
    expect(controller.nativeConnected, isTrue);
  });

}
