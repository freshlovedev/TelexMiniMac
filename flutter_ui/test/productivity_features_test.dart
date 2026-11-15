import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telexmini_ui/src/app.dart';
import 'package:telexmini_ui/src/controller.dart';
import 'package:telexmini_ui/src/text_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('text tools remain offline and deterministic', () {
    expect(TextToolbox.stripVietnamese('Tiếng Việt: ĐƯỢC'), 'Tieng Viet: DUOC');
    expect(TextToolbox.applyPure(' xin   chào ',TextTool.cleanSpaces),'xin chào');
    expect(TextToolbox.applyPure('xin chào',TextTool.uppercase),'XIN CHÀO');
    expect(TextToolbox.applyPure('XIN CHÀO',TextTool.lowercase),'xin chào');
    expect(TextToolbox.applyPure('xIN cHÀO',TextTool.titleCase),'Xin Chào');
    expect(TextToolbox.applyPure('xin. chào!',TextTool.sentenceCase),'Xin. Chào!');
    expect(TextToolbox.applyPure('• điều một',TextTool.markdown),'- điều một');
    expect(TextToolbox.applyPure('abc',TextTool.nfc),'abc');
    expect(TextToolbox.stripVietnamese('u\u031B\u0301'), 'u');
  });

  testWidgets('text tools page provides editable content and explicit actions', (tester) async {
    final directory=Directory.systemTemp.createTempSync('telexmini-text-tools');
    addTearDown(() async {if(await directory.exists())await directory.delete(recursive:true);});
    final c=AppController(settingsDirectoryOverride: directory.path);
    tester.view.physicalSize=const Size(1400,960);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(TelexMiniApp(controller:c));
    await c.setPage(AppPage.textTools);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Công cụ xử lý văn bản'),findsWidgets);
    expect(find.byKey(const Key('text-tool-editor')),findsOneWidget);
    await tester.enterText(find.byKey(const Key('text-tool-editor')),'xin chào');
    final textField=tester.widget<TextField>(find.byKey(const Key('text-tool-editor')));
    expect(textField.controller!.text,'xin chào');
    await tester.tap(find.byKey(const Key('text-tool-apply')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(),isNull);
  });

  testWidgets('typing lab verifies real-field output without persistent logs', (tester) async {
    final directory=Directory.systemTemp.createTempSync('telexmini-typing-lab');
    addTearDown(() async {if(await directory.exists())await directory.delete(recursive:true);});
    final c=AppController(settingsDirectoryOverride: directory.path);
    tester.view.physicalSize=const Size(1400,960);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(TelexMiniApp(controller:c));
    await c.setPage(AppPage.typingLab);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Typing Lab'),findsWidgets);
    await tester.enterText(find.byKey(const Key('typing-lab-input')),'ư');
    await tester.tap(find.byKey(const Key('typing-lab-check')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Đạt'),findsOneWidget);
    await tester.tap(find.byKey(const Key('typing-lab-next')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('nơ'),findsWidgets);
    expect(tester.takeException(),isNull);
  });

  test('new mode switches persist in isolated local settings', () async {
    final directory=Directory.systemTemp.createTempSync('telexmini-feature-preferences');
    try {
      final a=AppController(settingsDirectoryOverride:directory.path);
      a.instantRepairEnabled=false;
      a.adaptiveLearningEnabled=true;
      a.smartPunctuationEnabled=true;
      await a.save();
      final b=AppController(settingsDirectoryOverride:directory.path);
      await b.load();
      expect(b.instantRepairEnabled,isFalse);
      expect(b.adaptiveLearningEnabled,isTrue);
      expect(b.smartPunctuationEnabled,isTrue);
    } finally {
      if(await directory.exists())await directory.delete(recursive:true);
    }
  });
}
