import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telexmini_ui/src/app.dart';
import 'package:telexmini_ui/src/controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('resized windows keep every page usable and preserve About icon', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('telexmini-resize-');
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final controller = AppController(settingsDirectoryOverride: directory.path);
    // Includes the Windows minimum logical size (900x650), a narrow fallback
    // for small high-DPI monitors, and a wide default window (1220x830).
    const viewports = <(Size, double)>[
      (Size(1220, 830), 1.0),
      (Size(900, 650), 1.0),
      (Size(900, 650), 1.25),
      (Size(900, 650), 1.5),
      (Size(760, 470), 1.5),
    ];
    for (final (logical, scale) in viewports) {
      tester.view.devicePixelRatio = scale;
      tester.view.physicalSize = Size(
        logical.width * scale,
        logical.height * scale,
      );
      await tester.pumpWidget(TelexMiniApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 150));
      for (final page in AppPage.values) {
        await controller.setPage(page);
        await tester.pump(const Duration(milliseconds: 160));
        expect(
          tester.takeException(),
          isNull,
          reason:
              'Page ${page.name} overflowed at ${logical.width}x${logical.height} DPI $scale',
        );
        if (page == AppPage.about) {
          expect(find.byKey(const Key('about-nav-mark')), findsWidgets);
          expect(find.byKey(const Key('page-guide-about')), findsNothing);
        } else {
          expect(find.byKey(Key('page-guide-${page.name}')), findsOneWidget);
        }
      }
    }
  });
}
