#pragma once
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_set>
#include <vector>

namespace telexmini {

// No Win32, COM, clipboard or SendInput dependencies. The same composer can be
// embedded in a TSF text service, tested offline, or reused by another UI.
class Lexicon final {
 public:
  void AddEnglish(std::wstring_view word);
  void AddVietnamese(std::wstring_view word);
  bool LoadWordsFile(const std::wstring& path, bool vietnamese = false);
  bool HasEnglishPrefix(std::wstring_view word) const;
  bool IsEnglishWord(std::wstring_view word) const;
  bool IsKnownEnglishWord(std::wstring_view word) const;
  bool PreferVietnamesePrefix(std::wstring_view word) const;
  size_t WordCount() const noexcept { return english_.size(); }

 private:
  static std::wstring NormalizeAscii(std::wstring_view word);
  std::unordered_set<std::wstring> english_, prefixes_, vietnamese_, vi_prefixes_;
};

struct ComposerOptions {
  bool smart_english = true;
  bool english_first = false;
  bool vni = false;
  bool restore_invalid = true;
};

class Composer final {
 public:
  explicit Composer(const Lexicon* lexicon = nullptr);
  void Configure(ComposerOptions options) noexcept { options_ = options; }
  const ComposerOptions& Options() const noexcept { return options_; }
  const std::wstring& Text() const noexcept { return text_; }
  const std::wstring& Raw() const noexcept { return raw_; }
  void Reset();
  std::wstring Push(wchar_t key);
  void Backspace();
  std::wstring Finish() const;
  void RestoreLiteralWord(std::wstring word);

 private:
  enum class PrefixAction { Compose, ProtectEnglish, PreserveForeign };
  std::wstring PushCore(wchar_t key);
  std::wstring PushTelex(wchar_t key);
  std::wstring PushVni(wchar_t key);
  PrefixAction Classify(bool shape_now, bool tone_now) const;
  bool MustRecoverInvalid() const;
  void ApplyComposition(wchar_t key);
  std::wstring Literal(std::wstring value);

  const Lexicon* lexicon_;
  ComposerOptions options_{};
  std::wstring text_, raw_;
  std::optional<std::wstring> pending_escape_;
  bool literal_ = false, english_candidate_ = false, foreign_ = false;
  bool shaped_ = false, last_telex_ = false, last_tone_ = false;
};

// Independent EditPlan models range replacement without simulating real keys.
struct EditPlan {
  int erase = 0;
  std::wstring insert;
  static EditPlan Between(std::wstring_view previous, std::wstring_view current);
};

}  // namespace telexmini
