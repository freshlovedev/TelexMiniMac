import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telexmini_ui/src/app.dart';
import 'package:telexmini_ui/src/controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows 100 125 150 DPI retain navigation and editable pages',
      (tester) async {
    final directory = Directory.systemTemp.createTempSync('telexmini-dpi-');
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final controller = AppController(settingsDirectoryOverride: directory.path);
    for (final scale in <double>[1.0, 1.25, 1.5]) {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = scale;
      await tester.pumpWidget(TelexMiniApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 220));
      expect(tester.takeException(), isNull, reason:'Overview DPI $scale');

      if (scale == 1.5) {
        expect(find.byKey(const Key('compact-navigation')), findsOneWidget);
      } else {
        expect(find.byKey(const Key('compact-navigation')), findsNothing);
      }

      for(final page in <AppPage>[
        AppPage.textTools,
        AppPage.typingLab,
        AppPage.settings,
      ]) {
        await controller.setPage(page);
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull,
            reason:'Page $page failed at DPI $scale');
      }
      await controller.setPage(AppPage.overview);
    }
  });

  testWidgets('compact navigation offers all other settings pages',
      (tester) async {
    final directory = Directory.systemTemp.createTempSync('telexmini-nav-');
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    tester.view.physicalSize = const Size(800, 720);
    tester.view.devicePixelRatio = 1.5;
    final controller = AppController(settingsDirectoryOverride: directory.path);
    await tester.pumpWidget(TelexMiniApp(controller:controller));
    await tester.pump(const Duration(milliseconds: 220));
    final nav = find.byKey(const Key('compact-navigation'));
    expect(nav, findsOneWidget);
    // The last destination opens the in-app menu rather than hiding pages.
    await tester.tap(find.text('Thêm'));
    await tester.pump(); // Build the newly mounted modal first.
    await tester.pump(const Duration(milliseconds: 450)); // Complete sheet entry.
    expect(find.text('Chẩn đoán & sao lưu'), findsWidgets);
    expect(find.text('Cài đặt'), findsWidgets);
    // Select the first, immediately visible item. Lower items are reachable
    // by scrolling the sheet; this verifies the navigation callback itself.
    await tester.tap(find.text('Ưu tiên Telex').last);
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.page, AppPage.vietnamesePriority);
    expect(tester.takeException(), isNull);
  });
}
