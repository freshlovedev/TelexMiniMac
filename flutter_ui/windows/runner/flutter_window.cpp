#include "flutter_window.h"

#include <windows.h>
#include <winnls.h>
#include <commdlg.h>
#pragma comment(lib, "Comdlg32.lib")
#pragma comment(lib, "Normaliz.lib")
#include <tlhelp32.h>
#include <set>
#include <sstream>
#include <iterator>

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

bool ApplyPreferences(const EncodableMap* map) {
  // Apply all preferences in a single atomic preferences.ini replacement.
  // Previously each property performed its own read/replace/write.
  auto values = ReadSettings();
  const std::pair<const char*, const char*> booleans[] = {
      {"vietnameseEnabled", "VietnameseEnabled"},
      {"smartEnglish", "SmartEnglish"},
      {"restoreInvalid", "RestoreInvalid"},
      {"terminalEnglish", "AutoEnglish"},
      {"snippetsEnabled", "SnippetsEnabled"},
      {"instantRepairEnabled", "InstantRepairEnabled"},
      {"adaptiveLearningEnabled", "AdaptiveLearningEnabled"},
      {"smartPunctuationEnabled", "SmartPunctuationEnabled"},
      {"profilesEnabled", "ProfilesEnabled"},
      {"autoStart", "AutoStart"},
  };
  for (const auto& item : booleans) {
    if (auto value = ReadBool(map, item.first)) {
      values[item.second] = *value ? "true" : "false";
    }
  }
  const std::pair<const char*, const char*> strings[] = {
      {"inputMethod", "InputMethod"},
      {"languagePriority", "LanguagePriority"},
      {"hotkey", "Hotkey"},
      {"excludedApps", "ExcludedApps"},
  };
  for (const auto& item : strings) {
    if (auto value = ReadString(map, item.first)) values[item.second] = *value;
  }
  if (auto dark = ReadBool(map, "darkMode")) values["DarkTheme"] = *dark ? "true" : "false";
  if (auto english = ReadBool(map, "englishUI")) values["UILanguage"] = *english ? "en" : "vi";
  if (!WriteSettings(values)) return false;
  if (auto snippets = ReadString(map, "snippetText")) {
    const auto snippetPath = DataDirectory() / L"snippets.tsv";
    std::ifstream input(snippetPath, std::ios::binary);
    const std::string current((std::istreambuf_iterator<char>(input)),
                              std::istreambuf_iterator<char>());
    if (current != *snippets) {
      if (!WriteTextFile(L"snippets.tsv", *snippets)) return false;
      SignalEngineReload();
    }
  }
  return true;
}

void HandleTelexMiniMethodCall(
    const MethodCall<EncodableValue>& call,
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  const auto* arguments = call.arguments()
      ? std::get_if<EncodableMap>(call.arguments())
      : nullptr;
  if (call.method_name() == "normalizeNfc") {
    // Explicit request from Quick Text Tools. Does not read any text from
    // other windows, clipboard, or keyboard hooks.
    auto input=ReadString(arguments,"text");
    if(!input || input->size()>240000) {
      result->Error("INVALID_TEXT","Text is missing or exceeds the size limit.");
      return;
    }
    if(input->empty()) {result->Success(EncodableValue(std::string()));return;}
    const int units=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,
            input->data(),static_cast<int>(input->size()),nullptr,0);
    if(units<=0) {result->Error("INVALID_UTF8","Invalid text encoding.");return;}
    std::wstring wide(static_cast<size_t>(units),L'\0');
    if(MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,input->data(),
          static_cast<int>(input->size()),wide.data(),units)!=units) {
      result->Error("UTF8_ERROR","Cannot decode UTF-8.");return;
    }
    const int length=NormalizeString(NormalizationC,wide.data(),units,nullptr,0);
    if(length<=0) {result->Error("NFC_ERROR","Windows normalization failed.");return;}
    std::wstring nfc(static_cast<size_t>(length),L'\0');
    const int actual=NormalizeString(NormalizationC,wide.data(),units,nfc.data(),length);
    if(actual<=0) {result->Error("NFC_ERROR","Windows normalization failed.");return;}
    nfc.resize(actual);
    const int bytes=WideCharToMultiByte(CP_UTF8,0,nfc.data(),actual,nullptr,0,nullptr,nullptr);
    if(bytes<=0) {result->Error("ENCODING_ERROR","Cannot encode UTF-8.");return;}
    std::string utf8(static_cast<size_t>(bytes),'\0');
    WideCharToMultiByte(CP_UTF8,0,nfc.data(),actual,utf8.data(),bytes,nullptr,nullptr);
    result->Success(EncodableValue(std::move(utf8)));
    return;
  }
  if (call.method_name() == "closeUi") {
    result->Success(EncodableValue());
    ::PostQuitMessage(0);  // Only Flutter UI exits; native tray engine remains.
    return;
  }
  if (call.method_name() == "chooseExecutable") {
    wchar_t selected[MAX_PATH] = {};
    OPENFILENAMEW dialog = {};
    dialog.lStructSize = sizeof(dialog);
    dialog.hwndOwner = GetActiveWindow();
    dialog.lpstrFile = selected;
    dialog.nMaxFile = MAX_PATH;
    dialog.lpstrFilter = L"Windows executable (*.exe)\0*.exe\0All files (*.*)\0*.*\0";
    dialog.nFilterIndex = 1;
    dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
    if (GetOpenFileNameW(&dialog)) {
      const auto name = std::filesystem::path(selected).filename().wstring();
      const int len = WideCharToMultiByte(CP_UTF8, 0, name.c_str(),
          static_cast<int>(name.size()), nullptr, 0, nullptr, nullptr);
      if (len > 0) {
        std::string filename(static_cast<size_t>(len), '\0');
        WideCharToMultiByte(CP_UTF8, 0, name.c_str(),
            static_cast<int>(name.size()), filename.data(), len, nullptr, nullptr);
        result->Success(EncodableValue(filename));
      } else result->Success(EncodableValue());
    } else result->Success(EncodableValue());
    return;
  }
  if (call.method_name() == "listProcesses") {
    EncodableList names;
    std::set<std::wstring> unique;
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot != INVALID_HANDLE_VALUE) {
      PROCESSENTRY32W entry{};
      entry.dwSize = sizeof(entry);
      if (Process32FirstW(snapshot, &entry)) {
        do {
          const std::wstring name(entry.szExeFile);
          if (name.empty() || name.size() > 255) continue;
          unique.insert(name);
        } while (Process32NextW(snapshot, &entry));
      }
      CloseHandle(snapshot);
    }
    // Process executable names are converted to UTF-8 without touching
    // command lines, window contents, or keystrokes.
    for (const auto& wide : unique) {
      const int count = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                          static_cast<int>(wide.size()), nullptr, 0,
                                          nullptr, nullptr);
      if (count <= 0) continue;
      std::string name(static_cast<size_t>(count), '\0');
      WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                          static_cast<int>(wide.size()), name.data(), count,
                          nullptr, nullptr);
      names.emplace_back(name);
    }
    result->Success(EncodableValue(names));
    return;
  }
  if (call.method_name() == "loadProfiles") {
    std::ifstream input(DataDirectory() / L"profiles.tsv", std::ios::binary);
    std::string contents((std::istreambuf_iterator<char>(input)),
                         std::istreambuf_iterator<char>());
    result->Success(EncodableValue(contents));
    return;
  }
  if (call.method_name() == "saveProfiles") {
    const auto text = ReadString(arguments, "text");
    if (!text || text->size() > 65536) {
      result->Error("BAD_ARGUMENT", "Invalid profile data.");
      return;
    }
    std::set<std::string> names;
    std::istringstream lines(*text);
    std::string row;
    while (std::getline(lines, row)) {
      if (row.empty()) continue;
      const auto tab = row.find('\t');
      if (tab == std::string::npos || row.find('\t', tab + 1) != std::string::npos) {
        result->Error("BAD_ARGUMENT", "Profile rows require one tab.");
        return;
      }
      const std::string name = row.substr(0, tab);
      const std::string mode = row.substr(tab + 1);
      const bool valid = !name.empty() && name.size() <= 255 &&
        name.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-") == std::string::npos &&
        name.size() >= 5 && name.substr(name.size()-4) == ".exe" &&
        (mode == "English" || mode == "Vietnamese" || mode == "Balanced");
      if (!valid || !names.insert(name).second) {
        result->Error("BAD_ARGUMENT", "Invalid or duplicate process profile.");
        return;
      }
    }
    if (!WriteTextFile(L"profiles.tsv", *text)) {
      result->Error("LOCAL_STORAGE", "Cannot save profiles.");
      return;
    }
    SignalEngineReload();
    result->Success(EncodableValue());
    return;
  }
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
    if (!ApplyPreferences(arguments)) {
      result->Error("LOCAL_STORAGE", "Could not save native preferences.");
      return;
    }
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
