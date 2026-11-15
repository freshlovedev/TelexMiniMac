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
    const bool smart = flags.find("SmartEnglish=false") == std::string::npos;
    const bool englishFirst = flags.find("LanguagePriority=English") != std::string::npos;
    const bool restore = flags.find("RestoreInvalid=false") == std::string::npos;
    if (composer_) tm_configure(composer_, smart, englishFirst, vni_, restore);
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
            std::strcmp(name, "VietnameseOverrides.txt") == 0) {
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
    const std::string text = composer_ && tm_text(composer_) ? tm_text(composer_) : "";
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
  void commit() {
    if (composer_ && hasComposition(composer_)) {
      const char* final = tm_finish(composer_);
      if (final && *final) context_->commitString(final);
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
    if (!enabled_) return;
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
