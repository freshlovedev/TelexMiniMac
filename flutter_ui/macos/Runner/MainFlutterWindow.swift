import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let suite = UserDefaults(suiteName: "com.telexmini.mac") ?? .standard

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 1080, height: 680))
    self.minSize = NSSize(width: 960, height: 680)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerTelexMiniBridge(with: flutterViewController)

    super.awakeFromNib()
  }

  private func registerTelexMiniBridge(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.telexmini/control",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "WINDOW_CLOSED", message: "Settings window is unavailable.", details: nil))
        return
      }
      do {
        switch call.method {
        case "getStatus":
          result([
            "vietnameseEnabled": self.suite.object(forKey: "vietnameseEnabled") as? Bool ?? true,
            "automaticMode": true
          ])
        case "setMode":
          guard let args = call.arguments as? [String: Any],
                let enabled = args["vietnameseEnabled"] as? Bool else {
            result(FlutterError(code: "BAD_ARGUMENT", message: "Missing Vietnamese mode state.", details: nil))
            return
          }
          self.suite.set(enabled, forKey: "vietnameseEnabled")
          result(nil)
        case "applyPreferences":
          guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "BAD_ARGUMENT", message: "Expected a preferences map.", details: nil))
            return
          }
          self.applyPreferences(args)
          result(nil)
        case "loadDictionary":
          guard let args = call.arguments as? [String: Any],
                let vietnamese = args["vietnamese"] as? Bool else {
            result(FlutterError(code: "BAD_ARGUMENT", message: "Missing dictionary language.", details: nil))
            return
          }
          result(self.readDictionary(vietnamese: vietnamese))
        case "saveDictionary":
          guard let args = call.arguments as? [String: Any],
                let vietnamese = args["vietnamese"] as? Bool,
                let words = args["words"] as? [String] else {
            result(FlutterError(code: "BAD_ARGUMENT", message: "Expected dictionary language and words.", details: nil))
            return
          }
          try self.writeDictionary(words, vietnamese: vietnamese)
          result(nil)
        case "reloadEngine":
          try self.signalEngineReload()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "LOCAL_STORAGE", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func applyPreferences(_ values: [String: Any]) {
    let booleanKeys = [
      "smartEnglish", "restoreInvalid", "darkMode",
      "snippetsEnabled", "profilesEnabled", "vietnameseEnabled"
    ]
    for key in booleanKeys {
      if let value = values[key] as? Bool {
        suite.set(value, forKey: key)
      }
    }
    let stringKeys = ["inputMethod", "languagePriority", "excludedApps"]
    for key in stringKeys {
      if let value = values[key] as? String {
        suite.set(value, forKey: key)
      }
    }
    if let shortcut = values["hotkey"] as? String {
      let nativeShortcut = shortcut.replacingOccurrences(of: "Ctrl + Alt + V", with: "Ctrl + Option + V")
      suite.set(nativeShortcut, forKey: "hotkey")
    }
    if let englishUI = values["englishUI"] as? Bool {
      suite.set(englishUI ? "en" : "vi", forKey: "uiLanguage")
    }
    if let snippets = values["snippetText"] as? String,
       let validated = Self.validatedSnippetText(snippets) {
      try? Self.writeLocalFile(validated, named: "snippets.tsv")
    }
    try? signalEngineReload()
  }

  private func readDictionary(vietnamese: Bool) -> [String] {
    let name = vietnamese ? "VietnameseOverrides.txt" : "EnglishWords.txt"
    let directory = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/TelexMini", isDirectory: true)
    let file = directory.appendingPathComponent(name)
    guard let contents = try? String(contentsOf: file, encoding: .utf8) else { return [] }
    return contents.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.range(of: "^[a-z]{1,64}$", options: .regularExpression) != nil }
  }

  private func writeDictionary(_ words: [String], vietnamese: Bool) throws {
    let valid = words.map { $0.lowercased() }
      .filter { $0.range(of: "^[a-z]{1,64}$", options: .regularExpression) != nil }
      .sorted()
    let name = vietnamese ? "VietnameseOverrides.txt" : "EnglishWords.txt"
    try Self.writeLocalFile(valid.joined(separator: "\n") + (valid.isEmpty ? "" : "\n"), named: name)
    try signalEngineReload()
  }

  private func signalEngineReload() throws {
    try Self.writeLocalFile(Date().description, named: "dictionary-reload.flag")
  }

  private static func validatedSnippetText(_ source: String) -> String? {
    let lines = source.split(whereSeparator: \.isNewline)
    var output = [String]()
    for line in lines {
      let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
      guard parts.count == 2 else { return nil }
      let key = String(parts[0])
      let value = String(parts[1])
      guard key.range(of: "^[a-z]{2,48}$", options: .regularExpression) != nil,
            !value.isEmpty, value.count <= 1024 else { return nil }
      output.append(key + "\t" + value)
    }
    return output.joined(separator: "\n") + (output.isEmpty ? "" : "\n")
  }

  private static func writeLocalFile(_ contents: String, named name: String) throws {
    let directory = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/TelexMini", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let destination = directory.appendingPathComponent(name)
    try contents.write(to: destination, atomically: true, encoding: .utf8)
  }
}
