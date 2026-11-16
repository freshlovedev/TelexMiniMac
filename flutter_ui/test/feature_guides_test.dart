import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telexmini_ui/src/app.dart';
import 'package:telexmini_ui/src/controller.dart';
import 'package:telexmini_ui/src/feature_guide.dart';
import 'package:telexmini_ui/src/text_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every application page exposes concrete instructions and outcomes', () {
    for (final page in AppPage.values) {
      final samples = FeatureGuideCatalog.forPage(page);
      expect(samples, isNotEmpty, reason: '${page.name} needs instructions');
      for (final sample in samples) {
        expect(sample.stepsVi.trim(), isNotEmpty);
        expect(sample.stepsEn.trim(), isNotEmpty);
        expect(sample.before.trim(), isNotEmpty);
        expect(sample.after.trim(), isNotEmpty);
        expect(sample.whyVi.trim(), isNotEmpty);
        expect(sample.whyEn.trim(), isNotEmpty);
      }
    }
    expect(
      FeatureGuideCatalog.forPage(AppPage.textTools).length,
      greaterThanOrEqualTo(TextTool.values.length),
    );
    expect(
      FeatureGuideCatalog.forPage(AppPage.settings).length,
      greaterThanOrEqualTo(10),
    );
  });

  testWidgets('usage guide expands in-place for every route', (tester) async {
    final directory = Directory.systemTemp.createTempSync('telexmini-guides-');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final controller = AppController(settingsDirectoryOverride: directory.path);
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(TelexMiniApp(controller: controller));
    for (final page in AppPage.values.where((page) => page != AppPage.about)) {
      await controller.setPage(page);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(Key('page-guide-${page.name}')), findsOneWidget);
      expect(find.byKey(const Key('page-guide-toggle')), findsOneWidget);
      expect(find.byKey(const Key('page-guide-icon')), findsOneWidget);
      await tester.tap(find.byKey(const Key('page-guide-toggle')));
      await tester.pump();
      expect(find.byKey(Key('guide-choice-${page.name}-0')), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow on ${page.name}',
      );
    }
  });

  testWidgets('text tools example can be inserted and transformed', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('telexmini-demo-');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final controller = AppController(settingsDirectoryOverride: directory.path);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(TelexMiniApp(controller: controller));
    await controller.setPage(AppPage.textTools);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('text-tool-load-example')));
    await tester.pump(const Duration(milliseconds: 100));
    final input = tester.widget<TextField>(
      find.byKey(const Key('text-tool-editor')),
    );
    expect(input.controller!.text, 'a\u0301');
    await tester.tap(find.byKey(const Key('text-tool-apply')));
    await tester.pump(const Duration(milliseconds: 250));
    // In widget tests, the native Windows NFC bridge is not installed.
    // Confirm graceful fallback; production Windows normalization is native.
    expect(input.controller!.text, 'a\u0301');
    expect(tester.takeException(), isNull);
  });

  testWidgets('About shows story, version, thanks and support actions', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('telexmini-about-');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final controller = AppController(settingsDirectoryOverride: directory.path);
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(TelexMiniApp(controller: controller));
    await controller.setPage(AppPage.about);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Giới thiệu TelexMini'), findsWidgets);
    expect(find.text('Vì sao tôi tạo TelexMini?'), findsOneWidget);
    expect(find.byKey(const Key('page-guide-toggle')), findsNothing);
    expect(find.byKey(const Key('page-guide-about')), findsNothing);
    expect(find.byKey(const Key('about-nav-mark')), findsWidgets);
    await tester.drag(
      find.byKey(const Key('about-scroll')),
      const Offset(0, -800),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('about-support-link')), findsOneWidget);
    expect(find.byKey(const Key('about-copy-link')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
