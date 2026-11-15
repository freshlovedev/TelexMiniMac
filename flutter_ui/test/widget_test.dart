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
      case 'listProcesses':
        return <String>['notepad.exe','explorer.exe'];
      case 'loadProfiles':
        return '';
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

    expect(find.text('TelexMini'), findsOneWidget);
    expect(find.text('Chào mừng đến với TelexMini'), findsOneWidget);
    expect(find.text('Tùy chỉnh trải nghiệm'), findsOneWidget);
    expect(find.text('Thử gõ ngay'), findsOneWidget);
    expect(find.text('Từ điển Anh'), findsWidgets);
  });

  testWidgets('980x700 desktop layout has no overflow and uses custom icon', (tester) async {
    final controller = makeIsolatedController();
    tester.view.physicalSize = const Size(980, 700);
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

  testWidgets('narrow desktop layout uses responsive navigation', (tester) async {
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
    expect(find.byType(Sidebar), findsNothing);
    expect(find.byKey(const Key('compact-navigation')), findsOneWidget);
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

    expect(find.text('Tiếng Việt'), findsWidgets);
    await tester.tap(find.text('English').first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(controller.vietnameseEnabled, isFalse);
    expect(find.text('English'), findsWidgets);
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
    await tester.tap(find.text('Từ điển Anh').first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Chưa có từ tùy chỉnh'), findsOneWidget);
    await tester.tap(find.text('Thêm từ'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.byType(TextField).last, 'parameter');
    await tester.tap(find.text('Thêm').last);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.descendant(of: find.byType(ListTile), matching: find.text('parameter')), findsOneWidget);
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 150)));
    expect(calls.any((call) => call.method == 'saveDictionary'), isTrue);

    await tester.tap(find.byTooltip('Xóa từ'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.descendant(of: find.byType(ListTile), matching: find.text('parameter')), findsNothing);
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 150)));
    expect(calls.where((call) => call.method == 'saveDictionary').length, 2);
  });
  testWidgets('process manager opens from sidebar and lists running apps', (tester) async {
    final calls = <MethodCall>[];
    _installMockBridge(calls);
    addTearDown(_removeMockBridge);
    final controller = makeIsolatedController();
    tester.view.physicalSize = const Size(1080, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() => controller.load());
    await tester.pumpWidget(TelexMiniApp(controller: controller));
    await tester.tap(find.text('Ứng dụng & process'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Process đang chạy'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('notepad.exe'), findsOneWidget);
    expect(find.text('explorer.exe'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.excludedApps.isNotEmpty, isTrue);
    expect(calls.any((call) => call.method == 'applyPreferences'), isTrue);
  });

  testWidgets('per-app profile persists via native channel', (tester) async {
    final calls = <MethodCall>[];
    _installMockBridge(calls);
    addTearDown(_removeMockBridge);
    final controller = makeIsolatedController();
    await tester.runAsync(() => controller.load());
    await tester.runAsync(() => controller.saveProfiles('notepad.exe\tEnglish'));
    expect(controller.profilesText, 'notepad.exe\tEnglish');
    expect(calls.any((call) => call.method == 'saveProfiles'), isTrue);
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
    expect(find.text('Tiếng Việt'), findsWidgets);

    nativeVietnamese = false;
    await controller.refreshNativeMode();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('English'), findsWidgets);
    expect(controller.nativeConnected, isTrue);
  });

  testWidgets('snippets are managed as visible list rows, never a multiline editor', (tester) async {
    final calls = <MethodCall>[];
    _installMockBridge(calls);
    addTearDown(_removeMockBridge);
    final c = makeIsolatedController();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() => c.load());
    await tester.pumpWidget(TelexMiniApp(controller: c));
    await c.setPage(AppPage.snippets);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Danh sách gõ tắt'), findsOneWidget);
    await tester.tap(find.text('Thêm gõ tắt'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField).at(1), 'dc');
    await tester.enterText(find.byType(TextField).at(2), 'Địa chỉ:');
    await tester.tap(find.text('Lưu').last);
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.snippetText, contains('dc\tĐịa chỉ:'));
    expect(find.text('dc'), findsOneWidget);
    expect(find.text('Địa chỉ:'), findsOneWidget);
    expect(find.byTooltip('Sửa'), findsOneWidget);
    expect(find.byTooltip('Xóa'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('diagnostics is accessible in shared UI, compact sidebar toggles', (tester) async {
    final calls = <MethodCall>[];
    _installMockBridge(calls);
    addTearDown(_removeMockBridge);
    final c = makeIsolatedController();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() => c.load());
    await tester.pumpWidget(TelexMiniApp(controller:c));
    await c.setPage(AppPage.diagnostics);
    await tester.pump(const Duration(milliseconds:250));
    expect(find.text('Input Diagnostics'),findsOneWidget);
    expect(find.text('Sao lưu & Khôi phục'),findsOneWidget);
    await tester.tap(find.byTooltip('Thu gọn/mở rộng sidebar'));
    await tester.pump(const Duration(milliseconds:250));
    expect(c.compactSidebar,isTrue);
    expect(tester.takeException(),isNull);
  });

}
