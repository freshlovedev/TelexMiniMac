import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'controller.dart';

/// Local-only backup. Deliberately excludes typing history and diagnostic logs.
class BackupService {
  static Future<Directory> _directory(String? override) async {
    final dir = override != null
        ? Directory(override)
        : Directory('${Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'] ?? Directory.current.path}/TelexMini/Backups');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<File> create(AppController c, {String? directory}) async {
    final dir = await _directory(directory);
    final now = DateTime.now().toUtc();
    final stamp = now.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final file = File('${dir.path}/TelexMini-$stamp.json');
    final payload = <String, dynamic>{
      'format': 'telexmini-windows-backup',
      'schema': 1,
      'createdUtc': now.toIso8601String(),
      'settings': <String, dynamic>{
        'darkMode': c.darkMode,
        'englishUI': c.englishUI,
        'smartEnglish': c.smartEnglish,
        'restoreInvalid': c.restoreInvalid,
        'terminalEnglish': c.terminalEnglish,
        'snippetsEnabled': c.snippetsEnabled,
        'instantRepairEnabled': c.instantRepairEnabled,
        'adaptiveLearningEnabled': c.adaptiveLearningEnabled,
        'smartPunctuationEnabled': c.smartPunctuationEnabled,
        'profilesEnabled': c.profilesEnabled,
        'inputMethod': c.inputMethod,
        'languagePriority': c.languagePriority,
        'hotkey': c.hotkey,
        'excludedApps': c.excludedApps,
        'managedApps': c.managedApps,
        'snippetText': c.snippetText,
        'profilesText': c.profilesText,
        'englishWords': c.englishWords,
        'vietnameseWords': c.vietnameseWords,
      },
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    return file;
  }

  static Future<List<File>> list({String? directory}) async {
    final root = await _directory(directory);
    final entries = await root.list().where((e) => e is File && e.path.endsWith('.json')).cast<File>().toList();
    entries.sort((a,b) => b.path.compareTo(a.path));
    return entries;
  }

  static Future<void> restore(AppController c, File backup) async {
    final raw = jsonDecode(await backup.readAsString());
    if (raw is! Map || raw['format'] != 'telexmini-windows-backup' || raw['schema'] != 1 || raw['settings'] is! Map) {
      throw const FormatException('Invalid TelexMini backup format');
    }
    final d = Map<String, dynamic>.from(raw['settings'] as Map);
    String readString(String name, String fallback) {
      final v = d[name];
      if (v is! String) return fallback;
      return v;
    }
    bool readBool(String name, bool fallback) => d[name] is bool ? d[name] as bool : fallback;
    List<String> words(String key) {
      final value = d[key];
      if (value is! List) throw FormatException('Invalid $key');
      final normalized = value.map((e) => e.toString().trim().toLowerCase()).toList();
      if (normalized.any((s) => !RegExp(r'^[a-z]{1,64}$').hasMatch(s))) throw FormatException('Invalid $key');
      return normalized.toSet().toList()..sort();
    }

    final english = words('englishWords');
    final vietnamese = words('vietnameseWords');
    final input = readString('inputMethod', 'Telex');
    final priority = readString('languagePriority', 'Balanced');
    final shortcut = readString('hotkey', 'Ctrl + Shift + Space');
    if (!['Telex', 'VNI'].contains(input) || !['Balanced','English','Vietnamese'].contains(priority) ||
        !['Ctrl + Shift + Space', 'Ctrl + Alt + V', 'Alt + Shift + V'].contains(shortcut)) {
      throw const FormatException('Invalid input settings');
    }
    final snippets = readString('snippetText', '');
    final profiles = readString('profilesText', '');
    if (snippets.length > 65536 || profiles.length > 65536) throw const FormatException('Backup content too large');

    // Validate all user data before changing anything.
    final seen = <String>{};
    for (final line in snippets.split('\n').where((s) => s.isNotEmpty)) {
      final index = line.indexOf('\t');
      if (index < 2 || line.indexOf('\t', index+1) >= 0 ||
          !RegExp(r'^[a-zA-Z]{2,48}$').hasMatch(line.substring(0,index)) ||
          line.substring(index+1).isEmpty || line.substring(index+1).length > 1024 ||
          !seen.add(line.substring(0,index).toLowerCase())) {
        throw const FormatException('Invalid snippets');
      }
    }
    for (final line in profiles.split('\n').where((s) => s.isNotEmpty)) {
      final cells = line.split('\t');
      if (cells.length != 2 || !AppController.validProcessName(cells.first) ||
          !['English','Vietnamese','Balanced'].contains(cells.last)) {
        throw const FormatException('Invalid profiles');
      }
    }

    c.darkMode = readBool('darkMode', c.darkMode);
    c.englishUI = readBool('englishUI', c.englishUI);
    c.smartEnglish = readBool('smartEnglish', c.smartEnglish);
    c.restoreInvalid = readBool('restoreInvalid', c.restoreInvalid);
    c.terminalEnglish = readBool('terminalEnglish', c.terminalEnglish);
    c.snippetsEnabled = readBool('snippetsEnabled', c.snippetsEnabled);
    c.instantRepairEnabled = readBool('instantRepairEnabled', c.instantRepairEnabled);
    c.adaptiveLearningEnabled = readBool('adaptiveLearningEnabled', c.adaptiveLearningEnabled);
    c.smartPunctuationEnabled = readBool('smartPunctuationEnabled', c.smartPunctuationEnabled);
    c.profilesEnabled = readBool('profilesEnabled', c.profilesEnabled);
    c.inputMethod = input;
    c.languagePriority = priority;
    c.hotkey = shortcut;
    c.excludedApps = readString('excludedApps', '');
    c.managedApps = readString('managedApps', '');
    c.snippetText = snippets;
    c.englishWords..clear()..addAll(english);
    c.vietnameseWords..clear()..addAll(vietnamese);

    // Native stores profiles and dictionary in separate files.
    await c.saveProfiles(profiles);
    const channel = MethodChannel('com.telexmini/control');
    try {
      await channel.invokeMethod<void>('saveDictionary', {'vietnamese': false, 'words': english});
      await channel.invokeMethod<void>('saveDictionary', {'vietnamese': true, 'words': vietnamese});
    } on MissingPluginException {
      // Unit tests and non-Windows previews have no native bridge.
    }
    await c.save();
  }
}
