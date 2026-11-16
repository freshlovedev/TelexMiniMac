import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telexmini_ui/src/backup_service.dart';
import 'package:telexmini_ui/src/controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.telexmini/control');

  late Directory dir;
  late AppController controller;
  final calls = <String>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('telexmini-backup-test-');
    controller = AppController(settingsDirectoryOverride: dir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'loadDictionary') return <String>[];
      if (call.method == 'loadProfiles') return '';
      if (call.method == 'getStatus') return <String,dynamic>{'vietnameseEnabled':true,'automaticMode':true};
      return null;
    });
    await controller.load();
  });

  tearDown(() async {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    calls.clear();
    if (await dir.exists()) await dir.delete(recursive:true);
  });

  test('local JSON backup preserves dictionaries snippets profiles and settings', () async {
    controller.inputMethod = 'VNI';
    controller.languagePriority = 'English';
    controller.snippetText = 'dc\tĐịa chỉ:';
    controller.profilesText = 'notepad.exe\tEnglish';
    controller.managedApps = 'notepad.exe';
    controller.englishWords.add('boost');
    controller.vietnameseWords.add('been');
    final file = await BackupService.create(controller, directory: dir.path);
    expect(await file.exists(), true);
    final json = jsonDecode(await file.readAsString()) as Map<String,dynamic>;
    expect(json['format'], 'telexmini-windows-backup');
    expect((json['settings'] as Map)['snippetText'], 'dc\tĐịa chỉ:');
    expect((await BackupService.list(directory:dir.path)).length, 1);

    controller.inputMethod = 'Telex';
    controller.languagePriority = 'Balanced';
    controller.snippetText = '';
    controller.profilesText = '';
    controller.managedApps = '';
    controller.englishWords.clear();
    controller.vietnameseWords.clear();
    await BackupService.restore(controller,file);
    expect(controller.inputMethod,'VNI');
    expect(controller.languagePriority,'English');
    expect(controller.snippetText,'dc\tĐịa chỉ:');
    expect(controller.profilesText,'notepad.exe\tEnglish');
    expect(controller.managedApps,'notepad.exe');
    expect(controller.englishWords,contains('boost'));
    expect(controller.vietnameseWords,contains('been'));
    expect(calls,contains('saveDictionary'));
    expect(calls,contains('saveProfiles'));
    expect(calls,contains('saveSnippets'));
  });

  test('malformed backup never changes settings', () async {
    final path = File('${dir.path}/broken.json');
    await path.writeAsString('{"format":"bad","settings":{}}');
    final before = controller.inputMethod;
    await expectLater(BackupService.restore(controller,path),throwsFormatException);
    expect(controller.inputMethod,before);
  });

  test('invalid snippet backup rejected before altering settings', () async {
    final path = File('${dir.path}/bad-snippet.json');
    final baseline=await BackupService.create(controller,directory:dir.path);
    final obj=jsonDecode(await baseline.readAsString()) as Map<String,dynamic>;
    final settings=Map<String,dynamic>.from(obj['settings'] as Map);
    settings['snippetText']='invalid key\tbad';
    settings['inputMethod']='VNI';
    obj['settings']=settings;
    await path.writeAsString(jsonEncode(obj));
    await expectLater(BackupService.restore(controller,path),throwsFormatException);
    expect(controller.inputMethod,'Telex');
  });
}
