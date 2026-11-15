#include "c_api.h"
#include "core.h"
#include <memory>
#include <string>
#include <utility>

namespace {
std::wstring decode(const char* s) {
  std::wstring out;
  if (!s) return out;
  for (const auto* p = reinterpret_cast<const unsigned char*>(s); *p;) {
    uint32_t c = *p++;
    if (c < 0x80) { out.push_back(static_cast<wchar_t>(c)); continue; }
    unsigned count = (c >= 0xc2 && c <= 0xdf) ? 1 : (c >= 0xe0 && c <= 0xef) ? 2 : (c >= 0xf0 && c <= 0xf4) ? 3 : 0;
    if (!count) return {};
    uint32_t value = c & ((1U << (6 - count)) - 1U);
    for (unsigned i = 0; i < count; ++i) {
      if ((*p & 0xc0) != 0x80 || !*p) return {};
      value = (value << 6) | (*p++ & 0x3f);
    }
    if (value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff) ||
        (count == 1 && value < 0x80) || (count == 2 && value < 0x800) || (count == 3 && value < 0x10000))
      return {};
#if WCHAR_MAX <= 0xffff
    if (value > 0xffff) {
      value -= 0x10000;
      out.push_back(static_cast<wchar_t>(0xd800 + (value >> 10)));
      value = 0xdc00 + (value & 0x3ff);
    }
#endif
    out.push_back(static_cast<wchar_t>(value));
  }
  return out;
}
std::string encode(std::wstring_view text) {
  std::string out;
  for (size_t i = 0; i < text.size(); ++i) {
    uint32_t c = static_cast<uint32_t>(text[i]);
#if WCHAR_MAX <= 0xffff
    if (c >= 0xd800 && c <= 0xdbff && i + 1 < text.size()) {
      const auto lower = static_cast<uint32_t>(text[i + 1]);
      if (lower >= 0xdc00 && lower <= 0xdfff) {
        c = 0x10000 + ((c - 0xd800) << 10) + (lower - 0xdc00);
        ++i;
      }
    }
#endif
    if (c <= 0x7f) out.push_back(static_cast<char>(c));
    else if (c <= 0x7ff) {
      out.push_back(static_cast<char>(0xc0 | (c >> 6)));
      out.push_back(static_cast<char>(0x80 | (c & 0x3f)));
    } else if (c <= 0xffff) {
      out.push_back(static_cast<char>(0xe0 | (c >> 12)));
      out.push_back(static_cast<char>(0x80 | ((c >> 6) & 0x3f)));
      out.push_back(static_cast<char>(0x80 | (c & 0x3f)));
    } else if (c <= 0x10ffff) {
      out.push_back(static_cast<char>(0xf0 | (c >> 18)));
      out.push_back(static_cast<char>(0x80 | ((c >> 12) & 0x3f)));
      out.push_back(static_cast<char>(0x80 | ((c >> 6) & 0x3f)));
      out.push_back(static_cast<char>(0x80 | (c & 0x3f)));
    }
  }
  return out;
}
} // namespace

struct tm_composer {
  telexmini::Lexicon words;
  telexmini::Composer engine{&words};
  telexmini::ComposerOptions options{};
  std::wstring seed, english, vietnamese;
  std::string buffer;
  tm_composer(std::wstring s, std::wstring e, std::wstring v)
      : seed(std::move(s)), english(std::move(e)), vietnamese(std::move(v)) { reload(); }
  void reload() {
    engine.Reset();
    words = telexmini::Lexicon{};
    if (!seed.empty()) words.LoadWordsFile(seed);
    if (!english.empty()) words.LoadWordsFile(english);
    if (!vietnamese.empty()) words.LoadWordsFile(vietnamese, true);
    engine.Configure(options);
    buffer.clear();
  }
  const char* output(std::wstring_view value) {
    buffer = encode(value);
    return buffer.c_str();
  }
};

extern "C" {
uint32_t tm_api_version(void) { return 1; }
tm_composer* tm_create(const char* seed, const char* english, const char* vietnamese) {
  try { return new tm_composer(decode(seed), decode(english), decode(vietnamese)); }
  catch (...) { return nullptr; }
}
void tm_destroy(tm_composer* i) { delete i; }
int tm_configure(tm_composer* i, int smart, int first, int vni, int invalid) {
  if (!i) return 0;
  i->options = {smart != 0, first != 0, vni != 0, invalid != 0};
  i->engine.Configure(i->options);
  return 1;
}
int tm_reload(tm_composer* i) {
  if (!i) return 0;
  try { i->reload(); return 1; } catch (...) { return 0; }
}
void tm_reset(tm_composer* i) { if (i) i->engine.Reset(); }
void tm_backspace(tm_composer* i) { if (i) i->engine.Backspace(); }
const char* tm_push(tm_composer* i, uint32_t scalar) {
  if (!i || scalar > 0x10ffff || (scalar >= 0xd800 && scalar <= 0xdfff)) return nullptr;
  try {
    if (scalar > 0xffff) return i->output(i->engine.Text());
    i->engine.Push(static_cast<wchar_t>(scalar));
    return i->output(i->engine.Text());
  } catch (...) { return nullptr; }
}
const char* tm_text(tm_composer* i) { return i ? i->output(i->engine.Text()) : nullptr; }
const char* tm_raw(tm_composer* i) { return i ? i->output(i->engine.Raw()) : nullptr; }
const char* tm_finish(tm_composer* i) {
  if (!i) return nullptr;
  try { return i->output(i->engine.Finish()); } catch (...) { return nullptr; }
}
uint32_t tm_dictionary_size(tm_composer* i) {
  return i ? static_cast<uint32_t>(i->words.WordCount()) : 0;
}
}
