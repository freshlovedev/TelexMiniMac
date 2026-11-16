#include <fcitx/addonfactory.h>
#include <fcitx/inputmethodengine.h>
#include <fcitx/inputcontext.h>
#include <fcitx/inputcontextmanager.h>
#include <fcitx/inputpanel.h>
#include <fcitx/instance.h>
#include <fcitx/userinterfacemanager.h>
#include <fcitx-utils/keysym.h>
#include "c_api.h"
#include <cstdlib>
#include <fstream>
#include <filesystem>
#include <iterator>
#include <cstring>
#include <sys/inotify.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string>
#include <string_view>
#include <unordered_map>
#include <algorithm>
#include <cctype>
#include <chrono>
#include <iomanip>
#include <sstream>

namespace {
std::string configDirectory() {
  const char* qa = std::getenv("TELEXMINI_CONFIG_DIR");
  if (qa && *qa) return qa;
  const char* config = std::getenv("XDG_CONFIG_HOME");
  if (config && *config) return std::string(config) + "/telexmini";
  const char* home = std::getenv("HOME");
  return std::string(home ? home : "/nonexistent") + "/.config/telexmini";
}
std::string userPath(const char* name) {
  return configDirectory() + "/" + name;
}
std::string seedPath() {
  const char* source = std::getenv("TELEXMINI_LEXICON_PATH");
  // Used by private user-level QA builds; production uses the CMake install path.
  return source && *source ? std::string(source) : std::string(TELEXMINI_SEED_PATH);
}
bool hasComposition(tm_composer* c) {
  const char* s = tm_text(c);
  return s && *s;
}
class Composition : public fcitx::InputContextProperty {
 public:
  explicit Composition(fcitx::InputContext* ic)
      : context_(ic), composer_(tm_create(seedPath().c_str(),
             userPath("EnglishWords.txt").c_str(),
             userPath("VietnameseOverrides.txt").c_str())) {
    const auto directory = configDirectory();
    std::error_code error;
    std::filesystem::create_directories(directory, error);
    ::chmod(directory.c_str(), 0700);
    reloadSettings();
    // inotify is entirely event-driven. The non-blocking FD is drained on
    // the next physical key; no polling or filesystem I/O in the normal path.
    watch_fd_ = ::inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (watch_fd_ >= 0) {
      ::inotify_add_watch(watch_fd_, directory.c_str(),
          IN_CLOSE_WRITE | IN_MOVED_TO | IN_DELETE | IN_CREATE | IN_Q_OVERFLOW);
    }
  }
  ~Composition() override {
    if (watch_fd_ >= 0) ::close(watch_fd_);
    tm_destroy(composer_);
  }
  void reloadSettings() {
    std::ifstream settings(userPath("preferences.ini"));
    const std::string flags((std::istreambuf_iterator<char>(settings)),
                            std::istreambuf_iterator<char>());
    vni_ = flags.find("InputMethod=VNI") != std::string::npos;
    enabled_ = flags.find("VietnameseEnabled=false") == std::string::npos;
    terminal_english_ = flags.find("AutoEnglish=true") != std::string::npos;
    smart_ = flags.find("SmartEnglish=false") == std::string::npos;
    english_first_ = flags.find("LanguagePriority=English") != std::string::npos;
    vietnamese_first_ = flags.find("LanguagePriority=Vietnamese") != std::string::npos;
    restore_ = flags.find("RestoreInvalid=false") == std::string::npos;
    profiles_enabled_ = flags.find("ProfilesEnabled=true") != std::string::npos;
    profiles_.clear();
    if (profiles_enabled_) {
      std::ifstream source(userPath("profiles.tsv"));
      std::string line;
      while(std::getline(source,line) && profiles_.size() < 200) {
        const auto tab=line.find('\t');
        if(tab==std::string::npos || line.find('\t',tab+1)!=std::string::npos)continue;
        std::string key=line.substr(0,tab);
        std::string mode=line.substr(tab+1);
        std::transform(key.begin(),key.end(),key.begin(),[](unsigned char c) {
          return static_cast<char>(std::tolower(c));
        });
        if(!mode.empty() && mode.back()=='\r')mode.pop_back();
        if(key.empty() || key.size()>255 ||
            (mode!="English" && mode!="Vietnamese" && mode!="Balanced"))continue;
        profiles_[key]=mode;
      }
    }
    snippets_enabled_ = flags.find("SnippetsEnabled=true") != std::string::npos;
    snippets_.clear();
    std::ifstream snippetsFile(userPath("snippets.tsv"));
    std::string entry;
    while (std::getline(snippetsFile, entry) && snippets_.size()<256) {
      const auto tab=entry.find('\t');
      if(tab==std::string::npos || entry.find('\t',tab+1)!=std::string::npos) continue;
      const std::string key=entry.substr(0,tab);
      const std::string value=entry.substr(tab+1);
      if(key.size()<2 || key.size()>48 || value.empty() || value.size()>1024)continue;
      bool valid=true;
      for(char c:key) if(c<'a' || c>'z') {valid=false;break;}
      if(valid)snippets_[key]=value;
    }
    applyProfile();
  }
  void applyProfile() {
    if(!composer_)return;
    last_program_ = context_->program();
    std::string program=last_program_;
    const auto slash=program.find_last_of('/');
    if(slash!=std::string::npos)program=program.substr(slash+1);
    std::transform(program.begin(),program.end(),program.begin(),[](unsigned char c) {
      return static_cast<char>(std::tolower(c));
    });
    if(program.size()>4 && program.compare(program.size()-4,4,".exe")==0)
      program.resize(program.size()-4);
    auto it=profiles_.find(program);
    profile_mode_ = profiles_enabled_ && it!=profiles_.end() ? it->second : "Default";
    const bool english = profile_mode_=="English" ||
      (profile_mode_!="Vietnamese" && english_first_);
    const bool smart = profile_mode_=="Vietnamese" ? false :
      (smart_ && !vietnamese_first_);
    tm_configure(composer_,smart,english,vni_,restore_);
  }
  bool literalMode() const {
    if (!enabled_ || profile_mode_=="English") return true;
    if (!terminal_english_) return false;
    std::string app=last_program_;
    const auto slash=app.find_last_of('/');
    if (slash!=std::string::npos)app=app.substr(slash+1);
    std::transform(app.begin(),app.end(),app.begin(),[](unsigned char c) {
      return static_cast<char>(std::tolower(c));
    });
    static const char* terminals[] = {
      "gnome-terminal-server","gnome-terminal","kgx","konsole",
      "alacritty","kitty","ghostty","xterm","wezterm","foot","tilix"
    };
    for (const auto* name: terminals) if (app==name)return true;
    return false;
  }
  void maybeReload() {
    if (watch_fd_ < 0) return;
    bool dirty = false;
    alignas(inotify_event) char storage[4096]{};
    for (;;) {
      const ssize_t count = ::read(watch_fd_, storage, sizeof(storage));
      if (count <= 0) break;
      for (ssize_t pos = 0; pos + static_cast<ssize_t>(sizeof(inotify_event)) <= count;) {
        const auto* event = reinterpret_cast<const inotify_event*>(storage + pos);
        const char* name = event->len ? event->name : "";
        if ((event->mask & IN_Q_OVERFLOW) ||
            std::strcmp(name, "preferences.ini") == 0 ||
            std::strcmp(name, "dictionary-reload.flag") == 0 ||
            std::strcmp(name, "EnglishWords.txt") == 0 ||
            std::strcmp(name, "VietnameseOverrides.txt") == 0 ||
            std::strcmp(name, "snippets.tsv") == 0 ||
            std::strcmp(name, "profiles.tsv") == 0) {
          dirty = true;
        }
        pos += static_cast<ssize_t>(sizeof(inotify_event) + event->len);
      }
    }
    if (dirty) {
      commit();  // finish old preedit exactly once before changing semantics
      tm_reload(composer_);
      reloadSettings();
    }
  }
  void refresh() {
    auto &panel = context_->inputPanel();
    panel.reset();
    const char* composed = composer_ ?
        (literalMode() && snippets_enabled_
          ? tm_raw(composer_) : tm_text(composer_)) : nullptr;
    const std::string text = composed ? composed : "";
    if (!text.empty()) {
      if (context_->capabilityFlags().test(fcitx::CapabilityFlag::Preedit)) {
        panel.setClientPreedit(fcitx::Text(text));
      } else {
        panel.setPreedit(fcitx::Text(text));
      }
    }
    context_->updateUserInterface(fcitx::UserInterfaceComponent::InputPanel);
    context_->updatePreedit();
  }
  static void replaceMacro(std::string& text,const std::string& tag,
                           const std::string& value) {
    size_t pos=0;
    while((pos=text.find(tag,pos))!=std::string::npos) {
      text.replace(pos,tag.size(),value);
      pos+=value.size();
    }
  }
  std::string snippetFor(const std::string& raw) const {
    if(!snippets_enabled_)return "";
    auto it=snippets_.find(raw);
    if(it==snippets_.end())return "";
    auto expanded=it->second;
    if(expanded.find("{clipboard}")!=std::string::npos ||
       expanded.find("{cursor}")!=std::string::npos)return "";
    const auto now=std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
    std::tm local{};
    localtime_r(&now,&local);
    std::ostringstream date,time;
    date<<std::put_time(&local,"%Y-%m-%d");
    time<<std::put_time(&local,"%H:%M");
    std::ostringstream datetime;
    datetime<<std::put_time(&local,"%Y-%m-%d %H:%M");
    replaceMacro(expanded,"{date}",date.str());
    replaceMacro(expanded,"{time}",time.str());
    replaceMacro(expanded,"{datetime}",datetime.str());
    replaceMacro(expanded,"\\r\\n","\n");
    replaceMacro(expanded,"\\n","\n");
    replaceMacro(expanded,"\\t","\t");
    return expanded;
  }
  void commit() {
    if (composer_ && hasComposition(composer_)) {
      const std::string raw=tm_raw(composer_);
      const char* final = tm_finish(composer_);
      const std::string expanded=snippetFor(raw);
      if(!expanded.empty())context_->commitString(expanded);
      else if (literalMode()) context_->commitString(raw);
      else if (final && *final) context_->commitString(final);
    }
    if (composer_) tm_reset(composer_);
    refresh();
  }
  void reset() {
    if (composer_) tm_reset(composer_);
    refresh();
  }
  void keyEvent(fcitx::KeyEvent& event) {
    if (!composer_ || event.isRelease()) return;
    // Secure contexts must never receive a committed prior composition.
    if (context_->capabilityFlags().test(fcitx::CapabilityFlag::Password) ||
        context_->capabilityFlags().test(fcitx::CapabilityFlag::Sensitive)) {
      reset();
      return;
    }
    maybeReload();
    if (last_program_ != context_->program()) {
      if (hasComposition(composer_)) commit();
      applyProfile();
    }
    if (literalMode() && !snippets_enabled_) return;
    const auto key = event.key();
    // Preserve desktop shortcuts and application accelerators.
    if (key.states().test(fcitx::KeyState::Ctrl) ||
        key.states().test(fcitx::KeyState::Alt) ||
        key.states().test(fcitx::KeyState::Super)) {
      if (hasComposition(composer_)) commit();
      return;
    }
    const auto sym = static_cast<uint32_t>(key.sym());
    if (sym == FcitxKey_BackSpace && hasComposition(composer_)) {
      tm_backspace(composer_);
      refresh();
      event.filterAndAccept();
      return;
    }
    if (sym == FcitxKey_Escape && hasComposition(composer_)) {
      reset();
      event.filterAndAccept();
      return;
    }
    if ((sym >= 'a' && sym <= 'z') || (sym >= 'A' && sym <= 'Z') ||
        (vni_ && sym >= '1' && sym <= '9')) {
      if (std::string_view(tm_raw(composer_)).size() >= 63) commit();
      tm_push(composer_, sym);
      refresh();
      event.filterAndAccept();
      return;
    }
    if (hasComposition(composer_)) commit();
    // Pass delimiters (including Space, Enter, Tab) to the host exactly once.
  }
 private:
  fcitx::InputContext* context_;
  tm_composer* composer_;
  bool vni_ = false;
  bool enabled_ = true;
  bool snippets_enabled_ = false;
  bool smart_ = true;
  bool english_first_ = false;
  bool vietnamese_first_ = false;
  bool restore_ = true;
  bool profiles_enabled_ = false;
  bool terminal_english_ = false;
  std::string last_program_;
  std::string profile_mode_ = "Default";
  std::unordered_map<std::string,std::string> snippets_;
  std::unordered_map<std::string,std::string> profiles_;
  int watch_fd_ = -1;
};

class TelexMiniEngine final : public fcitx::InputMethodEngineV2 {
 public:
  explicit TelexMiniEngine(fcitx::Instance* instance)
      : factory_([](fcitx::InputContext& ic) { return new Composition(&ic); }) {
    instance->inputContextManager().registerProperty("telexminiComposition", &factory_);
  }
  void keyEvent(const fcitx::InputMethodEntry&, fcitx::KeyEvent& event) override {
    if (auto* ic = event.inputContext()) {
      ic->propertyFor(&factory_)->keyEvent(event);
    }
  }
  void reset(const fcitx::InputMethodEntry&, fcitx::InputContextEvent& event) override {
    if (auto* ic = event.inputContext()) ic->propertyFor(&factory_)->reset();
  }
 private:
  fcitx::FactoryFor<Composition> factory_;
};
class TelexMiniEngineFactory final : public fcitx::AddonFactory {
 public:
  fcitx::AddonInstance* create(fcitx::AddonManager* manager) override {
    return new TelexMiniEngine(manager->instance());
  }
};
} // namespace
FCITX_ADDON_FACTORY(TelexMiniEngineFactory);
