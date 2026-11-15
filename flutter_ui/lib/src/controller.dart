import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppPage { overview, englishDictionary, vietnamesePriority, snippets, symbols, settings }

class AppController extends ChangeNotifier {
  AppController({this.settingsDirectoryOverride});
  final String? settingsDirectoryOverride;
  static const _channel = MethodChannel('com.telexmini/control');
  Timer? _modeMonitor;
  bool _refreshingMode = false;
  bool _changingMode = false;

  AppPage page = AppPage.overview;
  bool darkMode = false;
  bool englishUI = false;
  bool vietnameseEnabled = true;
  bool automaticMode = true;
  bool smartEnglish = true;
  bool restoreInvalid = true;
  bool terminalEnglish = false;
  bool snippetsEnabled = false;
  bool profilesEnabled = false;
  bool autoStart = false;
  bool portableMode = false;
  bool nativeConnected = false;

  String inputMethod = 'Telex';
  String languagePriority = 'Balanced';
  String hotkey = 'Ctrl + Shift + Space';
  String excludedApps = '';
  String previewText = '';
  String snippetText = '';
  final List<String> englishWords = [];
  final List<String> vietnameseWords = [];
  final List<String> symbols = ['→','←','↑','↓','↔','✓','✕','★','☆','♥','©','®','™','°','±','∞','≠','≤','≥','…','—','·','€','£'];

  String t(String vi, String en) => englishUI ? en : vi;

  Future<void> load() async {
    final data = await _LocalSettings.read(settingsDirectoryOverride);
    darkMode = data['darkMode'] as bool? ?? false;
    englishUI = data['englishUI'] as bool? ?? false;
    vietnameseEnabled = data['vietnameseEnabled'] as bool? ?? true;
    automaticMode = data['automaticMode'] as bool? ?? true;
    smartEnglish = data['smartEnglish'] as bool? ?? true;
    restoreInvalid = data['restoreInvalid'] as bool? ?? true;
    terminalEnglish = data['terminalEnglish'] as bool? ?? false;
    snippetsEnabled = data['snippetsEnabled'] as bool? ?? false;
    profilesEnabled = data['profilesEnabled'] as bool? ?? false;
    autoStart = data['autoStart'] as bool? ?? false;
    portableMode = data['portableMode'] as bool? ?? false;
    inputMethod = data['inputMethod'] as String? ?? 'Telex';
    languagePriority = data['languagePriority'] as String? ?? 'Balanced';
    hotkey = data['hotkey'] as String? ?? 'Ctrl + Shift + Space';
    excludedApps = data['excludedApps'] as String? ?? '';
    snippetText = data['snippetText'] as String? ?? '';
    englishWords
      ..clear()
      ..addAll((data['englishWords'] as List<dynamic>? ?? englishWords).cast<String>());
    vietnameseWords
      ..clear()
      ..addAll((data['vietnameseWords'] as List<dynamic>? ?? vietnameseWords).cast<String>());
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>('getStatus');
      if (status != null) {
        nativeConnected = true;
        vietnameseEnabled = status['vietnameseEnabled'] as bool? ?? vietnameseEnabled;
        automaticMode = status['automaticMode'] as bool? ?? automaticMode;
      }
      final english = await _channel.invokeListMethod<String>('loadDictionary', {'vietnamese': false});
      final vietnamese = await _channel.invokeListMethod<String>('loadDictionary', {'vietnamese': true});
      if (english != null) englishWords..clear()..addAll(english);
      if (vietnamese != null) vietnameseWords..clear()..addAll(vietnamese);
    } on MissingPluginException {
      nativeConnected = false;
    } on PlatformException {
      nativeConnected = false;
    }
    notifyListeners();
  }

  void startNativeMonitoring() {
    _modeMonitor ??= Timer.periodic(
      const Duration(milliseconds: 450),
      (_) => unawaited(refreshNativeMode()),
    );
  }

  Future<void> refreshNativeMode() async {
    if (_refreshingMode || _changingMode) return;
    _refreshingMode = true;
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>('getStatus');
      if (status == null) return;
      final mode = status['vietnameseEnabled'] as bool? ?? vietnameseEnabled;
      final automatic = status['automaticMode'] as bool? ?? automaticMode;
      final changed = !nativeConnected ||
          vietnameseEnabled != mode || automaticMode != automatic;
      nativeConnected = true;
      vietnameseEnabled = mode;
      automaticMode = automatic;
      if (changed) notifyListeners();
    } on MissingPluginException {
      if (nativeConnected) {
        nativeConnected = false;
        notifyListeners();
      }
    } on PlatformException {
      if (nativeConnected) {
        nativeConnected = false;
        notifyListeners();
      }
    } finally {
      _refreshingMode = false;
    }
  }

  @override
  void dispose() {
    _modeMonitor?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _toJson() => {
    'schemaVersion': 1,
    'darkMode': darkMode,
    'englishUI': englishUI,
    'vietnameseEnabled': vietnameseEnabled,
    'automaticMode': automaticMode,
    'smartEnglish': smartEnglish,
    'restoreInvalid': restoreInvalid,
    'terminalEnglish': terminalEnglish,
    'snippetsEnabled': snippetsEnabled,
    'profilesEnabled': profilesEnabled,
    'autoStart': autoStart,
    'portableMode': portableMode,
    'inputMethod': inputMethod,
    'languagePriority': languagePriority,
    'hotkey': hotkey,
    'excludedApps': excludedApps,
    'snippetText': snippetText,
    'englishWords': englishWords,
    'vietnameseWords': vietnameseWords,
  };

  Future<void> save() async {
    final settings = _toJson();
    try {
      await _channel.invokeMethod<void>('applyPreferences', settings);
      nativeConnected = true;
    } on MissingPluginException {
      nativeConnected = false;
    } on PlatformException {
      nativeConnected = false;
    }
    await _LocalSettings.write(settings, settingsDirectoryOverride);
    notifyListeners();
  }

  Future<void> setVietnameseEnabled(bool value) async {
    _changingMode = true;
    vietnameseEnabled = value;
    notifyListeners();
    try {
      await _channel.invokeMethod<void>('setMode', {'vietnameseEnabled': value});
      nativeConnected = true;
    } on MissingPluginException {
      nativeConnected = false;
    } on PlatformException {
      nativeConnected = false;
    } finally {
      _changingMode = false;
    }
    await save();
  }

  Future<void> setPage(AppPage value) async {
    page = value;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    darkMode = !darkMode;
    await save();
  }

  Future<void> addWord(String word, {required bool vietnamese}) async {
    final normalized = word.trim().toLowerCase();
    if (normalized.isEmpty || !RegExp(r'^[a-z]{1,64}$').hasMatch(normalized)) return;
    final list = vietnamese ? vietnameseWords : englishWords;
    if (!list.contains(normalized)) {
      list.add(normalized);
      list.sort();
      notifyListeners();
      try {
        await _channel.invokeMethod<void>('saveDictionary', {
          'vietnamese': vietnamese,
          'words': list,
        });
        nativeConnected = true;
      } on MissingPluginException {
        nativeConnected = false;
      } on PlatformException {
        nativeConnected = false;
      }
      await save();
    }
  }

  Future<void> removeWord(String word, {required bool vietnamese}) async {
    final list = vietnamese ? vietnameseWords : englishWords;
    if (!list.remove(word)) return;
    notifyListeners();
    try {
      await _channel.invokeMethod<void>('saveDictionary', {
        'vietnamese': vietnamese,
        'words': list,
      });
      nativeConnected = true;
    } on MissingPluginException {
      nativeConnected = false;
    } on PlatformException {
      nativeConnected = false;
    }
    await save();
  }

  Future<void> copySymbol(String symbol) async {
    await Clipboard.setData(ClipboardData(text: symbol));
  }
}

class _LocalSettings {
  static Future<File> _file(String? overrideDirectory) async {
    late Directory directory;
    if (overrideDirectory != null) {
      directory = Directory(overrideDirectory);
    } else if (Platform.isWindows) {
      final root = Platform.environment['APPDATA'] ??
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['USERPROFILE'] ??
          Directory.current.path;
      directory = Directory('$root/TelexMini/FlutterUI');
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      directory = Directory('$home/Library/Application Support/TelexMini/FlutterUI');
    } else {
      final home = Platform.environment['XDG_CONFIG_HOME'] ??
          '${Platform.environment['HOME'] ?? Directory.current.path}/.config';
      directory = Directory('$home/telexmini');
    }
    await directory.create(recursive: true);
    return File('${directory.path}/settings.json');
  }

  static Future<Map<String, dynamic>> read(String? overrideDirectory) async {
    try {
      final file = await _file(overrideDirectory);
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> write(Map<String, dynamic> data, String? overrideDirectory) async {
    final file = await _file(overrideDirectory);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temporary.rename(file.path);
  }
}
