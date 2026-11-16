import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppPage {
  overview,
  englishDictionary,
  vietnamesePriority,
  snippets,
  symbols,
  applications,
  textTools,
  typingLab,
  diagnostics,
  settings,
  about,
}

class AppController extends ChangeNotifier {
  AppController({this.settingsDirectoryOverride});
  final String? settingsDirectoryOverride;
  static const _channel = MethodChannel('com.telexmini/control');
  Timer? _modeMonitor;
  Timer? _navigationMonitor;
  Timer? _statusDebounce;
  StreamSubscription<FileSystemEvent>? _preferenceEvents;
  StreamSubscription<FileSystemEvent>? _navigationEvents;
  bool _disposed = false;
  bool _watching = false;
  Future<void> checkNavigation() async {
    if (!Platform.isWindows) return;
    try {
      final root =
          Platform.environment['APPDATA'] ??
          Platform.environment['LOCALAPPDATA'];
      if (root == null) return;
      final file = File('$root/TelexMini/FlutterUI/navigation.txt');
      if (!await file.exists()) return;
      final name = (await file.readAsString()).trim();
      await file.delete();
      for (final candidate in AppPage.values) {
        if (candidate.name == name) {
          await setPage(candidate);
          break;
        }
      }
    } catch (_) {
      /* Do not interrupt the input engine on a navigation failure. */
    }
  }

  bool _refreshingMode = false;
  bool _changingMode = false;

  AppPage page = AppPage.overview;
  bool darkMode = false;
  bool compactSidebar = false;
  bool englishUI = false;
  bool vietnameseEnabled = true;
  bool automaticMode = true;
  bool smartEnglish = true;
  bool restoreInvalid = true;
  bool terminalEnglish = false;
  bool snippetsEnabled = false;
  bool instantRepairEnabled = true;
  bool adaptiveLearningEnabled = false;
  bool smartPunctuationEnabled = false;
  bool profilesEnabled = false;
  bool autoStart = false;
  bool portableMode = false;
  bool nativeConnected = false;

  String inputMethod = 'Telex';
  String languagePriority = 'Balanced';
  String hotkey = 'Ctrl + Shift + Space';
  String excludedApps = '';
  String managedApps = '';
  String previewText = '';
  String snippetText = '';
  String profilesText = '';
  final List<String> englishWords = [];
  final List<String> vietnameseWords = [];
  final List<String> symbols = [
    '→',
    '←',
    '↑',
    '↓',
    '↔',
    '✓',
    '✕',
    '★',
    '☆',
    '♥',
    '©',
    '®',
    '™',
    '°',
    '±',
    '∞',
    '≠',
    '≤',
    '≥',
    '…',
    '—',
    '·',
    '€',
    '£',
  ];

  String t(String vi, String en) => englishUI ? en : vi;

  static const languagePriorities = <String>[
    'Balanced',
    'Vietnamese',
    'English',
  ];

  Future<void> setLanguagePriority(String value) async {
    if (!languagePriorities.contains(value)) {
      throw const FormatException('Unsupported language priority');
    }
    if (languagePriority == value) return;
    final previous = languagePriority;
    languagePriority = value;
    notifyListeners();
    try {
      await save(requireNative: true);
    } catch (_) {
      languagePriority = previous;
      notifyListeners();
      rethrow;
    }
  }

  /// Snippets are stored in native snippets.tsv, not overwritten on every
  /// settings change. Commit in-memory state only after a successful save.
  Future<void> updateSnippets(String updated) async {
    if (updated.length > 65536) {
      throw const FormatException('Snippets exceed storage limits');
    }
    try {
      await _channel.invokeMethod<void>('saveSnippets', {'text': updated});
      nativeConnected = true;
    } on MissingPluginException {
      nativeConnected = false;
      if (Platform.isWindows && settingsDirectoryOverride == null) rethrow;
    } on PlatformException {
      nativeConnected = false;
      rethrow;
    }
    final firstSnippet = snippetText.isEmpty && updated.isNotEmpty;
    snippetText = updated;
    if (firstSnippet && !snippetsEnabled) snippetsEnabled = true;
    notifyListeners();
    await save();
  }

  Future<void> load() async {
    final data = await _LocalSettings.read(settingsDirectoryOverride);
    darkMode = data['darkMode'] as bool? ?? false;
    compactSidebar = data['compactSidebar'] as bool? ?? false;
    englishUI = data['englishUI'] as bool? ?? false;
    vietnameseEnabled = data['vietnameseEnabled'] as bool? ?? true;
    automaticMode = data['automaticMode'] as bool? ?? true;
    smartEnglish = data['smartEnglish'] as bool? ?? true;
    restoreInvalid = data['restoreInvalid'] as bool? ?? true;
    terminalEnglish = data['terminalEnglish'] as bool? ?? false;
    snippetsEnabled = data['snippetsEnabled'] as bool? ?? false;
    instantRepairEnabled = data['instantRepairEnabled'] as bool? ?? true;
    adaptiveLearningEnabled = data['adaptiveLearningEnabled'] as bool? ?? false;
    smartPunctuationEnabled = data['smartPunctuationEnabled'] as bool? ?? false;
    profilesEnabled = data['profilesEnabled'] as bool? ?? false;
    autoStart = data['autoStart'] as bool? ?? false;
    portableMode = data['portableMode'] as bool? ?? false;
    inputMethod = data['inputMethod'] as String? ?? 'Telex';
    languagePriority = data['languagePriority'] as String? ?? 'Balanced';
    hotkey = data['hotkey'] as String? ?? 'Ctrl + Shift + Space';
    excludedApps = data['excludedApps'] as String? ?? '';
    managedApps = data['managedApps'] as String? ?? '';
    snippetText = data['snippetText'] as String? ?? '';
    profilesText = data['profilesText'] as String? ?? '';
    englishWords
      ..clear()
      ..addAll(
        (data['englishWords'] as List<dynamic>? ?? englishWords).cast<String>(),
      );
    vietnameseWords
      ..clear()
      ..addAll(
        (data['vietnameseWords'] as List<dynamic>? ?? vietnameseWords)
            .cast<String>(),
      );
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );
      if (status != null) {
        nativeConnected = true;
        vietnameseEnabled =
            status['vietnameseEnabled'] as bool? ?? vietnameseEnabled;
        automaticMode = status['automaticMode'] as bool? ?? automaticMode;
        final priority = status['languagePriority'] as String?;
        if (priority != null && languagePriorities.contains(priority)) {
          languagePriority = priority;
        }
      }
      final english = await _channel.invokeListMethod<String>(
        'loadDictionary',
        {'vietnamese': false},
      );
      final vietnamese = await _channel.invokeListMethod<String>(
        'loadDictionary',
        {'vietnamese': true},
      );
      if (english != null) {
        englishWords
          ..clear()
          ..addAll(english);
      }
      if (vietnamese != null) {
        vietnameseWords
          ..clear()
          ..addAll(vietnamese);
      }
      profilesText =
          await _channel.invokeMethod<String>('loadProfiles') ?? profilesText;
      final nativeSnippets = await _channel.invokeMethod<String>(
        'loadSnippets',
      );
      if (nativeSnippets != null) {
        snippetText = nativeSnippets;
      } else if (snippetText.isNotEmpty) {
        await _channel.invokeMethod<void>('saveSnippets', {
          'text': snippetText,
        });
      }
    } on MissingPluginException {
      nativeConnected = false;
    } on PlatformException {
      nativeConnected = false;
    }
    notifyListeners();
  }

  /// The native process writes preferences.ini atomically for hotkey and tray
  /// changes. Watch those events rather than calling the native bridge 5
  /// times per second. Long-period polling remains only as a fallback.
  void startNativeMonitoring() {
    if (_disposed) return;
    _navigationMonitor ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(checkNavigation()),
    );
    _modeMonitor ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(refreshNativeMode()),
    );
    unawaited(checkNavigation());
    if (!_watching && Platform.isWindows) {
      _watching = true;
      unawaited(_startFileWatchers());
    }
  }

  Future<void> _startFileWatchers() async {
    final local =
        settingsDirectoryOverride ??
        '${Platform.environment['LOCALAPPDATA'] ?? Directory.current.path}/TelexMini';
    final roaming = Platform.environment['APPDATA'];
    try {
      final prefs = Directory(local);
      await prefs.create(recursive: true);
      if (_disposed) return;
      _preferenceEvents = prefs.watch().listen(
        (event) {
          if (!event.path.toLowerCase().contains('preferences.ini')) return;
          _statusDebounce?.cancel();
          _statusDebounce = Timer(
            const Duration(milliseconds: 40),
            () => unawaited(refreshNativeMode()),
          );
        },
        onError: (_) {
          /* The five-second safety poll remains active. */
        },
      );
      if (settingsDirectoryOverride == null && roaming != null) {
        final navigation = Directory('$roaming/TelexMini/FlutterUI');
        await navigation.create(recursive: true);
        if (_disposed) return;
        _navigationEvents = navigation.watch().listen(
          (event) {
            if (event.path.toLowerCase().endsWith('navigation.txt')) {
              // File creation can be signalled before the writer has closed it.
              unawaited(
                Future<void>.delayed(const Duration(milliseconds: 45))
                    .then((_) => checkNavigation()),
              );
            }
          },
          onError: (_) {
            /* The navigation safety poll remains active. */
          },
        );
      }
    } on FileSystemException {
      // Network profiles and locked directories still work via fallback polls.
    }
  }

  Future<void> refreshNativeMode() async {
    if (_refreshingMode || _changingMode) return;
    _refreshingMode = true;
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );
      if (status == null) return;
      final mode = status['vietnameseEnabled'] as bool? ?? vietnameseEnabled;
      final automatic = status['automaticMode'] as bool? ?? automaticMode;
      final externalPriority = status['languagePriority'] as String?;
      final nextPriority =
          externalPriority != null &&
              languagePriorities.contains(externalPriority)
          ? externalPriority
          : languagePriority;
      final changed =
          !nativeConnected ||
          vietnameseEnabled != mode ||
          automaticMode != automatic ||
          languagePriority != nextPriority;
      nativeConnected = true;
      vietnameseEnabled = mode;
      automaticMode = automatic;
      languagePriority = nextPriority;
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
    _disposed = true;
    _modeMonitor?.cancel();
    _navigationMonitor?.cancel();
    _statusDebounce?.cancel();
    unawaited(_preferenceEvents?.cancel());
    unawaited(_navigationEvents?.cancel());
    super.dispose();
  }

  Map<String, dynamic> _toJson() => {
    'schemaVersion': 1,
    'darkMode': darkMode,
    'compactSidebar': compactSidebar,
    'englishUI': englishUI,
    'vietnameseEnabled': vietnameseEnabled,
    'automaticMode': automaticMode,
    'smartEnglish': smartEnglish,
    'restoreInvalid': restoreInvalid,
    'terminalEnglish': terminalEnglish,
    'snippetsEnabled': snippetsEnabled,
    'instantRepairEnabled': instantRepairEnabled,
    'adaptiveLearningEnabled': adaptiveLearningEnabled,
    'smartPunctuationEnabled': smartPunctuationEnabled,
    'profilesEnabled': profilesEnabled,
    'autoStart': autoStart,
    'portableMode': portableMode,
    'inputMethod': inputMethod,
    'languagePriority': languagePriority,
    'hotkey': hotkey,
    'excludedApps': excludedApps,
    'managedApps': managedApps,
    'snippetText': snippetText,
    'profilesText': profilesText,
    'englishWords': englishWords,
    'vietnameseWords': vietnameseWords,
  };

  Future<void> save({bool requireNative = false}) async {
    final settings = _toJson();
    try {
      await _channel.invokeMethod<void>('applyPreferences', settings);
      nativeConnected = true;
    } on MissingPluginException {
      nativeConnected = false;
      if (requireNative &&
          Platform.isWindows &&
          settingsDirectoryOverride == null) {
        rethrow;
      }
    } on PlatformException {
      nativeConnected = false;
      if (requireNative) rethrow;
    }
    await _LocalSettings.write(settings, settingsDirectoryOverride);
    notifyListeners();
  }

  /// Closing Flutter releases the desktop UI process. The independent
  /// native TelexMini tray engine continues handling keys.
  Future<void> closeSettingsWindow() async {
    try {
      await _channel.invokeMethod<void>('closeUi');
    } on MissingPluginException {
      /* Only available on Windows runner. */
    }
  }

  Future<String?> chooseExecutable() async {
    try {
      return await _channel.invokeMethod<String>('chooseExecutable');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<List<String>> runningProcesses() async {
    try {
      final names =
          await _channel.invokeListMethod<String>('listProcesses') ??
          <String>[];
      return names.toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } on MissingPluginException {
      return [];
    } on PlatformException {
      return [];
    }
  }

  static bool validProcessName(String name) {
    final pattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,254}');
    if (pattern.stringMatch(name) != name) return false;
    return !Platform.isWindows || name.toLowerCase().endsWith('.exe');
  }

  Future<void> saveProfiles(String text) async {
    final lines = <String>[];
    final seen = <String>{};
    for (final raw in text.split('\n')) {
      if (raw.trim().isEmpty) continue;
      final fields = raw.trim().split('\t');
      if (fields.length != 2 ||
          !validProcessName(fields[0]) ||
          !['English', 'Vietnamese', 'Balanced'].contains(fields[1]) ||
          !seen.add(fields[0].toLowerCase())) {
        throw const FormatException('Invalid application profile');
      }
      lines.add(fields.join('\t'));
    }
    if (lines.length > 200) throw const FormatException('Too many profiles');
    final normalized = lines.join('\n');
    await _channel.invokeMethod<void>('saveProfiles', {'text': normalized});
    profilesText = normalized;
    await save();
  }

  Future<void> setVietnameseEnabled(bool value) async {
    _changingMode = true;
    vietnameseEnabled = value;
    notifyListeners();
    try {
      await _channel.invokeMethod<void>('setMode', {
        'vietnameseEnabled': value,
      });
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

  Future<void> toggleCompactSidebar() async {
    compactSidebar = !compactSidebar;
    await save();
  }

  Future<void> addWord(String word, {required bool vietnamese}) async {
    final normalized = word.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized.length > 64 ||
        RegExp(r'^[a-z]+').stringMatch(normalized) != normalized) {
      throw const FormatException(
        'Dictionary words must be 1–64 ASCII letters',
      );
    }
    final list = vietnamese ? vietnameseWords : englishWords;
    if (list.contains(normalized)) return;
    final next = [...list, normalized]..sort();
    try {
      await _channel.invokeMethod<void>('saveDictionary', {
        'vietnamese': vietnamese,
        'words': next,
      });
      nativeConnected = true;
    } on MissingPluginException {
      nativeConnected = false;
      if (Platform.isWindows && settingsDirectoryOverride == null) rethrow;
    } on PlatformException {
      nativeConnected = false;
      rethrow;
    }
    list
      ..clear()
      ..addAll(next);
    notifyListeners();
    await save();
  }

  Future<void> removeWord(String word, {required bool vietnamese}) async {
    final list = vietnamese ? vietnameseWords : englishWords;
    if (!list.contains(word)) return;
    final next = [...list]..remove(word);
    try {
      await _channel.invokeMethod<void>('saveDictionary', {
        'vietnamese': vietnamese,
        'words': next,
      });
      nativeConnected = true;
    } on MissingPluginException {
      nativeConnected = false;
      if (Platform.isWindows && settingsDirectoryOverride == null) rethrow;
    } on PlatformException {
      nativeConnected = false;
      rethrow;
    }
    list
      ..clear()
      ..addAll(next);
    notifyListeners();
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
      final root =
          Platform.environment['APPDATA'] ??
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['USERPROFILE'] ??
          Directory.current.path;
      directory = Directory('$root/TelexMini/FlutterUI');
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      directory = Directory(
        '$home/Library/Application Support/TelexMini/FlutterUI',
      );
    } else {
      final home =
          Platform.environment['XDG_CONFIG_HOME'] ??
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

  static Future<void> write(
    Map<String, dynamic> data,
    String? overrideDirectory,
  ) async {
    final file = await _file(overrideDirectory);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temporary.rename(file.path);
  }
}
