import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telexmini_ui/src/app.dart';
import 'package:telexmini_ui/src/controller.dart';
import 'package:telexmini_ui/src/typing_lab_page.dart';

const channel = MethodChannel('com.telexmini/control');

class _MockNative {
  _MockNative({this.diskSnippets = 'dc\tĐịa chỉ:'});
  String diskSnippets;
  String priority = 'Balanced';
  bool rejectDictionary = false;
  bool rejectSnippets = false;
  bool rejectPreferences = false;
  bool autoStart = false;
  int snippetWrites = 0;
  final calls = <MethodCall>[];
  final english = <String>[];
  final vietnamese = <String>[];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'getStatus':
        return <String, Object>{
          'vietnameseEnabled': true,
          'automaticMode': true,
          'languagePriority': priority,
          'autoStart': autoStart,
        };
      case 'loadDictionary':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        return args['vietnamese'] == true ? vietnamese : english;
      case 'loadProfiles':
        return '';
      case 'loadSnippets':
        return diskSnippets;
      case 'saveSnippets':
        if (rejectSnippets) {
          throw PlatformException(
            code: 'LOCAL_STORAGE',
            message: 'disk unavailable',
          );
        }
        snippetWrites++;
        diskSnippets = (call.arguments as Map)['text'] as String;
        return null;
      case 'saveDictionary':
        if (rejectDictionary) {
          throw PlatformException(
            code: 'LOCAL_STORAGE',
            message: 'disk unavailable',
          );
        }
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final target = args['vietnamese'] == true ? vietnamese : english;
        target
          ..clear()
          ..addAll((args['words'] as List).cast<String>());
        return null;
      case 'applyPreferences':
        if (rejectPreferences) {
          throw PlatformException(
            code: 'LOCAL_STORAGE',
            message: 'login item not available',
          );
        }
        priority = (call.arguments as Map)['languagePriority'] as String;
        autoStart = (call.arguments as Map)['autoStart'] as bool? ?? autoStart;
        return null;
      default:
        return null;
    }
  }
}

AppController _isolated() {
  final directory = Directory.systemTemp.createTempSync(
    'telexmini-input-test-',
  );
  addTearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });
  return AppController(settingsDirectoryOverride: directory.path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native snippets remain canonical across unrelated settings writes',
    () async {
      final mock = _MockNative(diskSnippets: 'abc\tNative source');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, mock.handle);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final controller = _isolated();
      // Simulate an outdated Flutter JSON snapshot from the old implementation.
      controller.snippetText = 'old\tOld value';
      await controller.save(); // Mock native bridge ignores stale snippetText.
      mock.calls.clear();

      await controller.load();
      expect(controller.snippetText, 'abc\tNative source');
      await controller.setLanguagePriority('English');
      await controller.save();
      expect(
        mock.snippetWrites,
        0,
        reason: 'Changing input priority must not rewrite snippets.tsv',
      );

      await controller.updateSnippets('abc\tUpdated value');
      expect(mock.diskSnippets, 'abc\tUpdated value');
      expect(mock.snippetWrites, 1);
      expect(controller.snippetText, 'abc\tUpdated value');
    },
  );

  test(
    'first snippet enables expansion and failed writes never appear saved',
    () async {
      final mock = _MockNative(diskSnippets: '');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, mock.handle);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final controller = _isolated();
      await controller.load();
      expect(controller.snippetsEnabled, false);
      mock.rejectSnippets = true;
      await expectLater(
        controller.updateSnippets('dc\tĐịa chỉ:'),
        throwsA(isA<PlatformException>()),
      );
      expect(controller.snippetText, isEmpty);
      expect(controller.snippetsEnabled, false);
      mock.rejectSnippets = false;
      await controller.updateSnippets('dc\tĐịa chỉ:');
      expect(controller.snippetText, 'dc\tĐịa chỉ:');
      expect(controller.snippetsEnabled, true);
      expect(mock.snippetWrites, 1);
    },
  );

  test(
    'English dictionary changes are transactional with platform failures',
    () async {
      final mock = _MockNative();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, mock.handle);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final controller = _isolated();
      await controller.load();
      mock.rejectDictionary = true;
      await expectLater(
        controller.addWord('boostlab', vietnamese: false),
        throwsA(isA<PlatformException>()),
      );
      expect(controller.englishWords, isEmpty);
      mock.rejectDictionary = false;
      await controller.addWord('boostlab', vietnamese: false);
      expect(controller.englishWords, ['boostlab']);
      expect(mock.english, ['boostlab']);
      mock.rejectDictionary = true;
      await expectLater(
        controller.removeWord('boostlab', vietnamese: false),
        throwsA(isA<PlatformException>()),
      );
      expect(controller.englishWords, ['boostlab']);
      mock.rejectDictionary = false;
      await controller.removeWord('boostlab', vietnamese: false);
      expect(controller.englishWords, isEmpty);
      expect(mock.english, isEmpty);
    },
  );

  test(
    'desktop autostart reflects real native registration failures',
    () async {
      final mock = _MockNative();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, mock.handle);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final controller = _isolated();
      await controller.load();
      expect(controller.autoStart, false);
      mock.rejectPreferences = true;
      await expectLater(
        controller.setAutoStart(true),
        throwsA(isA<PlatformException>()),
      );
      expect(controller.autoStart, false);
      expect(mock.autoStart, false);
      mock.rejectPreferences = false;
      await controller.setAutoStart(true);
      expect(controller.autoStart, true);
      expect(mock.autoStart, true);
      await controller.setAutoStart(false);
      expect(controller.autoStart, false);
      expect(mock.autoStart, false);
    },
  );

  test('real composer oracle scenarios differ in all three priorities', () {
    expect(
      LabModeCases.forMode('Balanced')
          .firstWhere((e) => e.typed == 'been')
          .expected,
      'bên',
    );
    expect(
      LabModeCases.forMode('Vietnamese')
          .firstWhere((e) => e.typed == 'boost')
          .expected,
      'bốt',
    );
    expect(
      LabModeCases.forMode('English')
          .firstWhere((e) => e.typed == 'been')
          .expected,
      'been',
    );
    expect(
      LabModeCases.forMode('English')
          .firstWhere((e) => e.typed == 'now')
          .expected,
      'now',
    );
    expect(
      LabModeCases.forMode('English')
          .firstWhere((e) => e.typed == 'ddang')
          .expected,
      'đang',
    );
  });

  testWidgets(
    'Overview and Typing Lab use shared priority and show all examples',
    (tester) async {
      final mock = _MockNative();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, mock.handle);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final controller = _isolated();
      tester.view.physicalSize = const Size(1400, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.runAsync(() => controller.load());
      await tester.pumpWidget(TelexMiniApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('priority-Balanced')), findsOneWidget);
      expect(find.byKey(const Key('priority-Vietnamese')), findsOneWidget);
      expect(find.byKey(const Key('priority-English')), findsOneWidget);

      await tester.runAsync(() => controller.setLanguagePriority('Vietnamese'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.languagePriority, 'Vietnamese');

      await controller.setPage(AppPage.typingLab);
      await tester.pump(const Duration(milliseconds: 250));
      for (final mode in AppController.languagePriorities) {
        expect(find.byKey(Key('lab-mode-card-$mode')), findsOneWidget);
        expect(find.byKey(Key('priority-$mode')), findsOneWidget);
      }
      expect(find.textContaining('bốt'), findsWidgets);
      await tester.runAsync(() => controller.setLanguagePriority('English'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('been'), findsWidgets);
      expect(find.byKey(const Key('typing-lab-input')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await controller.setPage(AppPage.overview);
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.languagePriority, 'English');
      expect(find.byKey(const Key('priority-English')), findsOneWidget);

      await controller.setPage(AppPage.applications);
      await tester.pump(const Duration(milliseconds: 250));
      if (Platform.isLinux) {
        expect(find.text('Chọn EXE'), findsNothing);
        expect(find.textContaining('IBus'), findsWidgets);
      }
      if (Platform.isMacOS) {
        expect(find.text('Chọn .app'), findsOneWidget);
      }

      await controller.setPage(AppPage.settings);
      await tester.pump(const Duration(milliseconds: 250));
      if (Platform.isLinux || Platform.isMacOS) {
        expect(find.text('Sửa nhanh từ vừa gõ'), findsNothing);
        expect(find.textContaining('Sửa từ sau khi commit'), findsWidgets);
      } else {
        expect(find.text('Sửa nhanh từ vừa gõ'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
