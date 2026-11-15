#include "flutter_window.h"

#include <windows.h>

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <map>
#include <optional>
#include <string>
#include <system_error>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResult;

std::filesystem::path DataDirectory() {
  wchar_t buffer[32768] = {};
  DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", buffer, 32768);
  if (length == 0 || length >= 32768) {
    length = GetEnvironmentVariableW(L"USERPROFILE", buffer, 32768);
  }
  std::filesystem::path root =
      (length > 0 && length < 32768) ? std::filesystem::path(buffer)
                                     : std::filesystem::current_path();
  const auto directory = root / L"TelexMini";
  std::error_code error;
  std::filesystem::create_directories(directory, error);
  return directory;
}

std::filesystem::path SettingsPath() {
  return DataDirectory() / L"preferences.ini";
}

std::map<std::string, std::string> ReadSettings() {
  std::map<std::string, std::string> values;
  std::ifstream input(SettingsPath(), std::ios::binary);
  std::string line;
  while (std::getline(input, line)) {
    // Native WinForms preferences use CRLF; binary getline retains the CR.
    // Without trimming, "false\\r" would be treated as true by the bridge.
    while (!line.empty() && (line.back() == '\r' || line.back() == '\n')) {
      line.pop_back();
    }
    if (line.size() >= 3 &&
        static_cast<unsigned char>(line[0]) == 0xEF &&
        static_cast<unsigned char>(line[1]) == 0xBB &&
        static_cast<unsigned char>(line[2]) == 0xBF) {
      line.erase(0, 3);
    }
    const auto separator = line.find('=');
    if (separator == std::string::npos || separator == 0) continue;
    values[line.substr(0, separator)] = line.substr(separator + 1);
  }
  return values;
}

bool WriteSettings(const std::map<std::string, std::string>& values) {
  const auto path = SettingsPath();
  const auto temporary = path.wstring() + L".tmp";
  {
    std::ofstream output(std::filesystem::path(temporary), std::ios::binary | std::ios::trunc);
    if (!output) return false;
    for (const auto& item : values) output << item.first << "=" << item.second << "\n";
    output.flush();
    if (!output.good()) return false;
  }
  return MoveFileExW(temporary.c_str(), path.c_str(),
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
}

void SetSetting(const std::string& key, const std::string& value) {
  auto values = ReadSettings();
  values[key] = value;
  WriteSettings(values);
}

bool WriteTextFile(const std::wstring& name, const std::string& content) {
  const auto path = DataDirectory() / name;
  const auto temporary = path.wstring() + L".tmp";
  {
    std::ofstream output(std::filesystem::path(temporary), std::ios::binary | std::ios::trunc);
    if (!output) return false;
    output.write(content.data(), static_cast<std::streamsize>(content.size()));
    output.flush();
    if (!output.good()) return false;
  }
  return MoveFileExW(temporary.c_str(), path.c_str(),
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
}

const EncodableValue* Find(const EncodableMap* map, const char* key) {
  if (!map) return nullptr;
  const auto found = map->find(EncodableValue(std::string(key)));
  return found == map->end() ? nullptr : &found->second;
}

std::optional<bool> ReadBool(const EncodableMap* map, const char* key) {
  const auto* value = Find(map, key);
  if (!value) return std::nullopt;
  if (const auto* result = std::get_if<bool>(value)) return *result;
  return std::nullopt;
}

std::optional<std::string> ReadString(const EncodableMap* map, const char* key) {
  const auto* value = Find(map, key);
  if (!value) return std::nullopt;
  if (const auto* result = std::get_if<std::string>(value)) return *result;
  return std::nullopt;
}

std::vector<std::string> ReadWords(const EncodableMap* map) {
  std::vector<std::string> words;
  const auto* value = Find(map, "words");
  const auto* list = value ? std::get_if<EncodableList>(value) : nullptr;
  if (!list) return words;
  for (const auto& item : *list) {
    if (const auto* word = std::get_if<std::string>(&item)) {
      std::string normalized = *word;
      std::transform(normalized.begin(), normalized.end(), normalized.begin(),
                     [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
      if (!normalized.empty() && normalized.size() <= 64 &&
          std::all_of(normalized.begin(), normalized.end(),
                      [](unsigned char c) { return c >= 'a' && c <= 'z'; })) {
        words.push_back(normalized);
      }
    }
  }
  std::sort(words.begin(), words.end());
  words.erase(std::unique(words.begin(), words.end()), words.end());
  return words;
}

void SignalEngineReload() {
  WriteTextFile(L"dictionary-reload.flag", "reload\n");
}

void ApplyPreferences(const EncodableMap* map) {
  const std::pair<const char*, const char*> booleans[] = {
      {"vietnameseEnabled", "VietnameseEnabled"},
      {"smartEnglish", "SmartEnglish"},
      {"restoreInvalid", "RestoreInvalid"},
      {"terminalEnglish", "AutoEnglish"},
      {"snippetsEnabled", "SnippetsEnabled"},
      {"profilesEnabled", "ProfilesEnabled"},
      {"autoStart", "AutoStart"},
  };
  for (const auto& item : booleans) {
    if (auto value = ReadBool(map, item.first)) SetSetting(item.second, *value ? "true" : "false");
  }
  const std::pair<const char*, const char*> strings[] = {
      {"inputMethod", "InputMethod"},
      {"languagePriority", "LanguagePriority"},
      {"hotkey", "Hotkey"},
      {"excludedApps", "ExcludedApps"},
  };
  for (const auto& item : strings) {
    if (auto value = ReadString(map, item.first)) SetSetting(item.second, *value);
  }
  if (auto dark = ReadBool(map, "darkMode")) SetSetting("DarkTheme", *dark ? "true" : "false");
  if (auto english = ReadBool(map, "englishUI")) SetSetting("UILanguage", *english ? "en" : "vi");
  if (auto snippets = ReadString(map, "snippetText")) {
    WriteTextFile(L"snippets.tsv", *snippets);
  }
  SignalEngineReload();
}

void HandleTelexMiniMethodCall(
    const MethodCall<EncodableValue>& call,
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  const auto* arguments = call.arguments()
      ? std::get_if<EncodableMap>(call.arguments())
      : nullptr;
  if (call.method_name() == "getStatus") {
    const auto values = ReadSettings();
    const auto found = values.find("VietnameseEnabled");
    const bool enabled = found == values.end() || found->second != "false";
    EncodableMap status;
    status[EncodableValue("vietnameseEnabled")] = EncodableValue(enabled);
    status[EncodableValue("automaticMode")] = EncodableValue(true);
    result->Success(EncodableValue(status));
    return;
  }
  if (call.method_name() == "setMode") {
    auto enabled = ReadBool(arguments, "vietnameseEnabled");
    if (!enabled) {
      result->Error("BAD_ARGUMENT", "Missing Vietnamese mode state.");
      return;
    }
    SetSetting("VietnameseEnabled", *enabled ? "true" : "false");
    result->Success(EncodableValue());
    return;
  }
  if (call.method_name() == "applyPreferences") {
    if (!arguments) {
      result->Error("BAD_ARGUMENT", "Expected a preferences map.");
      return;
    }
    ApplyPreferences(arguments);
    result->Success(EncodableValue());
    return;
  }
  if (call.method_name() == "loadDictionary") {
    auto vietnamese = ReadBool(arguments, "vietnamese");
    if (!vietnamese) {
      result->Error("BAD_ARGUMENT", "Missing dictionary language.");
      return;
    }
    const auto name = *vietnamese ? L"VietnameseOverrides.txt" : L"EnglishWords.txt";
    std::ifstream input(DataDirectory() / name, std::ios::binary);
    EncodableList words;
    std::string word;
    while (std::getline(input, word)) {
      if (!word.empty() && word.size() <= 64 &&
          std::all_of(word.begin(), word.end(),
                      [](unsigned char c) { return c >= 'a' && c <= 'z'; })) {
        words.emplace_back(word);
      }
    }
    result->Success(EncodableValue(words));
    return;
  }
  if (call.method_name() == "saveDictionary") {
    auto vietnamese = ReadBool(arguments, "vietnamese");
    if (!vietnamese) {
      result->Error("BAD_ARGUMENT", "Missing dictionary language.");
      return;
    }
    const auto words = ReadWords(arguments);
    std::string contents;
    for (const auto& word : words) contents += word + "\n";
    const bool saved = WriteTextFile(*vietnamese ? L"VietnameseOverrides.txt" : L"EnglishWords.txt", contents);
    if (!saved) {
      result->Error("LOCAL_STORAGE", "Could not save dictionary file.");
      return;
    }
    SignalEngineReload();
    result->Success(EncodableValue());
    return;
  }
  if (call.method_name() == "reloadEngine") {
    SignalEngineReload();
    result->Success(EncodableValue());
    return;
  }
  result->NotImplemented();
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  telexmini_channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.telexmini/control",
      &flutter::StandardMethodCodec::GetInstance());
  telexmini_channel_->SetMethodCallHandler(HandleTelexMiniMethodCall);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });
  flutter_controller_->ForceRedraw();
  return true;
}

void FlutterWindow::OnDestroy() {
  telexmini_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) return *result;
  }
  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
