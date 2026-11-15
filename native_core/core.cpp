#include "core.h"
#include <algorithm>
#include <array>
#include <cwctype>
#include <fstream>
#include <filesystem>
#include <string>
#include <utility>

namespace telexmini {
namespace {
constexpr std::array<std::wstring_view, 12> kRows{{
    L"aáàảãạ", L"ăắằẳẵặ", L"âấầẩẫậ",
    L"eéèẻẽẹ", L"êếềểễệ", L"iíìỉĩị",
    L"oóòỏõọ", L"ôốồổỗộ", L"ơớờởỡợ",
    L"uúùủũụ", L"ưứừửữự", L"yýỳỷỹỵ"
}};
constexpr std::array<std::wstring_view, 12> kUpperRows{{
    L"AÁÀẢÃẠ", L"ĂẮẰẲẴẶ", L"ÂẤẦẨẪẬ",
    L"EÉÈẺẼẸ", L"ÊẾỀỂỄỆ", L"IÍÌỈĨỊ",
    L"OÓÒỎÕỌ", L"ÔỐỒỔỖỘ", L"ƠỚỜỞỠỢ",
    L"UÚÙỦŨỤ", L"ƯỨỪỬỮỰ", L"YÝỲỶỸỴ"
}};
constexpr std::wstring_view kBases = L"aăâeêioôơuưy";

wchar_t Lower(wchar_t c) {
  if (c >= L'A' && c <= L'Z') return c - L'A' + L'a';
  for (size_t row=0; row<kRows.size(); ++row) {
    for (size_t col=0; col<kUpperRows[row].size(); ++col)
      if (kUpperRows[row][col]==c) return kRows[row][col];
  }
  return c;
}
bool IsUpper(wchar_t c) {
  if (c >= L'A' && c <= L'Z') return true;
  for (auto row:kUpperRows) if (row.find(c)!=row.npos)return true;
  return false;
}
wchar_t Case(wchar_t target,wchar_t original) {
  if (!IsUpper(original))return target;
  if(target>=L'a' && target<=L'z')return target-L'a'+L'A';
  for(size_t row=0;row<kRows.size();++row) {
    auto col=kRows[row].find(target);
    if(col!=std::wstring_view::npos)return kUpperRows[row][col];
  }
  return target;
}
bool Contains(std::wstring_view set,wchar_t c) {
  return set.find(c)!=std::wstring_view::npos;
}
int Row(wchar_t c) {
  c=Lower(c);
  for(size_t row=0;row<kRows.size();++row)
    if(Contains(kRows[row],c))return static_cast<int>(row);
  return -1;
}
wchar_t Base(wchar_t c) {
  const int row=Row(c);
  return row<0?Lower(c):kRows[row][0];
}
int Tone(wchar_t c) {
  c=Lower(c);
  for(auto row:kRows) {
    auto col=row.find(c);
    if(col!=row.npos)return static_cast<int>(col);
  }
  return 0;
}
wchar_t Mark(wchar_t c,int tone) {
  const int r=Row(c);
  return r<0?c:Case(kRows[r][static_cast<size_t>(tone)],c);
}
wchar_t Shape(wchar_t c,wchar_t target) {
  auto i=kBases.find(target);
  return i==kBases.npos?c:Case(kRows[i][Tone(c)],c);
}
std::vector<int> Vowels(std::wstring_view text) {
  std::vector<int> v;
  v.reserve(6);
  for(size_t i=0;i<text.size();++i)
    if(Row(text[i])>=0)v.push_back(static_cast<int>(i));
  if(v.size()>1 && v[0]==1 &&
     ((Lower(text[0])==L'q' && Base(text[1])==L'u') ||
      (Lower(text[0])==L'g' && Base(text[1])==L'i'))) v.erase(v.begin());
  return v;
}
int TonePosition(std::wstring_view text) {
  auto v=Vowels(text);
  if(v.empty())return -1;
  for(int i=static_cast<int>(v.size())-1;i>=0;--i)
    if(Contains(L"ăâêôơ",Base(text[v[i]])))return v[i];
  for(int i=static_cast<int>(v.size())-1;i>=0;--i)
    if(Base(text[v[i]])==L'ư')return v[i];
  if(v.size()==1)return v[0];
  if(v.size()>=3)return v[v.size()-2];
  const std::wstring pair{Base(text[v[0]]),Base(text[v[1]])};
  const bool closed=static_cast<size_t>(v.back())<text.size()-1;
  return closed || pair==L"oa" || pair==L"oe" || pair==L"uy"? v[1]:v[0];
}
std::wstring SetTone(std::wstring text,int tone) {
  const int target=TonePosition(text);
  for(size_t i=0;i<text.size();++i)
    if(Row(text[i])>=0) text[i]=Mark(text[i],i==static_cast<size_t>(target)?tone:0);
  return text;
}
std::wstring Normalize(std::wstring text) {
  int tone=0;
  for(auto c:text)if(Tone(c))tone=Tone(c);
  return SetTone(std::move(text),tone);
}
std::wstring Plain(std::wstring_view text) {
  std::wstring word;word.reserve(text.size());
  for(auto c:text)word+=Base(c);
  return word;
}
bool ListHas(std::wstring_view list,std::wstring_view word) {
  std::wstring key;key.reserve(word.size()+2);
  key+=L'|';key+=word;key+=L'|';
  return list.find(key)!=std::wstring_view::npos;
}
bool HasForeignStart(std::wstring_view text) {
  if(text.size()<2)return false;
  auto first=Lower(text[0]),second=Lower(text[1]);
  if(Contains(L"fjwz",first))return true;
  if(first==L'p' && second!=L'h')return true;
  return ListHas(L"|bl|br|cl|cr|dr|fl|fr|gl|gr|pl|pr|sc|sk|sl|sm|sn|sp|st|sw|tw|wh|wr|kn|ps|pt|",
                 std::wstring{first,second});
}
bool ImpossibleVietnamese(std::wstring_view text) {
  auto word=Plain(text);
  size_t first=0;
  while(first<word.size() && !Contains(kBases,word[first]))++first;
  if(first==word.size())return false;
  auto onset=word.substr(0,first);
  if(!ListHas(L"||b|c|ch|d|đ|g|gh|h|k|kh|l|m|n|ng|ngh|nh|p|ph|q|r|s|t|th|tr|v|x|",onset))
    return true;
  size_t end=first;
  while(end<word.size() && Contains(kBases,word[end]))++end;
  auto ending=word.substr(end);
  for(auto c:ending)if(Contains(kBases,c))return true;
  return !ListHas(L"||c|ch|m|n|ng|nh|p|t|",ending);
}
bool LooksVietnamese(std::wstring_view text) {
  auto word=Plain(text);
  size_t first=0;
  while(first<word.size() && !Contains(kBases,word[first]))++first;
  if(first==word.size())return false;
  auto onset=word.substr(0,first);
  if(!onset.empty() && !ListHas(L"|b|c|ch|d|đ|g|gh|h|k|kh|l|m|n|ng|ngh|nh|p|ph|q|r|s|t|th|tr|v|x|",onset))
    return false;
  size_t end=first;
  while(end<word.size() && Contains(kBases,word[end]))++end;
  auto ending=word.substr(end);
  if(!ending.empty() && !ListHas(L"|c|ch|m|n|ng|nh|p|t|",ending))return false;
  auto cluster=word.substr(first,end-first);
  if(onset==L"q") {
    if(cluster.size()<2 || cluster[0]!=L'u')return false;
    cluster.erase(cluster.begin());
  }
  if(onset==L"g" && cluster.size()>1 && cluster[0]==L'i')
    cluster.erase(cluster.begin());
  return ListHas(L"|a|ă|â|e|ê|i|o|ô|ơ|u|ư|y|ai|ao|au|ay|âu|ây|eo|êu|ia|iê|iu|oa|oă|oe|oi|oo|ôô|ôi|ơi|ua|uă|uâ|uê|ui|uo|uô|uơ|uy|ưa|ưi|ưu|ươ|yê|iêu|oai|oao|oay|oeo|uao|uây|uôi|uya|uyê|uyu|ươi|ươu|yêu|uyêu|",
                 cluster);
}
bool ImmediateShape(std::wstring_view word) {
  if(word.size()<2)return false;
  auto last=Lower(word.back());
  return Contains(L"aeo",last) && Lower(word[word.size()-2])==last;
}
bool ImmediateW(std::wstring_view composed,wchar_t key) {
  if(Lower(key)!=L'w')return false;
  if(composed.empty())return true;
  for(auto c:composed)if(Contains(L"auoăươ",Base(c)))return true;
  return false;
}
bool ImmediateTone(std::wstring_view raw,wchar_t key) {
  if(!Contains(L"sfrxj",Lower(key)) || raw.empty() ||
     ImpossibleVietnamese(raw))return false;
  for(auto c:raw)if(Row(c)>=0)return true;
  return false;
}
bool VowelAfterTone(std::wstring_view raw,wchar_t key) {
  return Contains(L"aeiouy",Lower(key)) && raw.size()>=2 &&
         Contains(L"sfrxj",Lower(raw.back()));
}
}  // namespace

std::wstring Lexicon::NormalizeAscii(std::wstring_view word) {
  if(word.empty() || word.size()>64)return {};
  std::wstring out;out.reserve(word.size());
  for(auto c:word) {
    if(c>=L'A' && c<=L'Z')c=c-L'A'+L'a';
    if(c<L'a' || c>L'z')return {};
    out+=c;
  }
  return out;
}
void Lexicon::AddEnglish(std::wstring_view word) {
  auto item=NormalizeAscii(word);
  if(item.empty() || !english_.insert(item).second)return;
  for(size_t i=1;i<item.size();++i)prefixes_.insert(item.substr(0,i));
}
void Lexicon::AddVietnamese(std::wstring_view word) {
  auto item=NormalizeAscii(word);
  if(item.empty() || !vietnamese_.insert(item).second)return;
  for(size_t i=1;i<item.size();++i)vi_prefixes_.insert(item.substr(0,i));
}
bool Lexicon::LoadWordsFile(const std::wstring& path,bool vietnamese) {
  std::ifstream input{std::filesystem::path(path)};
  if(!input)return false;
  std::string line;
  while(std::getline(input,line)) {
    auto comment=line.find('#');
    if(comment!=std::string::npos)line.erase(comment);
    std::wstring word;
    for(auto c:line) {
      if(c==' ' || c=='\t' || c=='\r')continue;
      word+=static_cast<unsigned char>(c);
    }
    if(vietnamese)AddVietnamese(word);
    else AddEnglish(word);
  }
  return true;
}
bool Lexicon::HasEnglishPrefix(std::wstring_view word) const {
  auto w=NormalizeAscii(word);
  return !w.empty() && !vietnamese_.count(w) &&
         (english_.count(w)!=0 || prefixes_.count(w)!=0);
}
bool Lexicon::IsEnglishWord(std::wstring_view word) const {
  auto w=NormalizeAscii(word);
  return !w.empty() && !vietnamese_.count(w) && english_.count(w)!=0;
}
bool Lexicon::IsKnownEnglishWord(std::wstring_view word) const {
  auto w=NormalizeAscii(word);
  return !w.empty() && english_.count(w)!=0;
}
bool Lexicon::PreferVietnamesePrefix(std::wstring_view word) const {
  auto w=NormalizeAscii(word);
  return !w.empty() &&
         (vietnamese_.count(w)!=0 || vi_prefixes_.count(w)!=0);
}

Composer::Composer(const Lexicon* dictionary):lexicon_(dictionary) { Reset(); }
void Composer::Reset() {
  text_.clear();raw_.clear();pending_escape_.reset();
  literal_=english_candidate_=foreign_=shaped_=last_telex_=last_tone_=false;
}
void Composer::RestoreLiteralWord(std::wstring word) {
  Reset();text_=word;raw_=std::move(word);literal_=true;
}
void Composer::Backspace() {
  if(!text_.empty())text_.pop_back();
  raw_=text_;
  english_candidate_=options_.smart_english && lexicon_ &&
                     lexicon_->HasEnglishPrefix(raw_);
  foreign_=options_.smart_english && HasForeignStart(raw_);
  shaped_=text_!=raw_;
  last_telex_=last_tone_=false;
  pending_escape_.reset();
  if(text_.empty())literal_=false;
}
std::wstring Composer::Literal(std::wstring text) {
  literal_=true;text_=std::move(text);return text_;
}
bool Composer::MustRecoverInvalid() const {
  return options_.smart_english && !options_.vni && !literal_ &&
         !(lexicon_ && lexicon_->PreferVietnamesePrefix(raw_)) &&
         raw_!=text_ && ImpossibleVietnamese(text_);
}
Composer::PrefixAction Composer::Classify(bool shape_now,bool tone_now) const {
  if(!options_.smart_english || options_.vni || literal_ ||
     (lexicon_ && lexicon_->PreferVietnamesePrefix(raw_)))
    return PrefixAction::Compose;
  if(foreign_ || HasForeignStart(raw_))return PrefixAction::PreserveForeign;
  const bool recognized=lexicon_ && lexicon_->IsEnglishWord(raw_);
  if(!shape_now && !tone_now &&
     (!shaped_ || (recognized && (options_.english_first || !LooksVietnamese(text_)))) &&
     lexicon_ && lexicon_->HasEnglishPrefix(raw_))
    return PrefixAction::ProtectEnglish;
  return PrefixAction::Compose;
}
void Composer::ApplyComposition(wchar_t key) {
  if(english_candidate_) {
    english_candidate_=false;
    auto raw=raw_;
    text_.clear();literal_=false;
    for(auto c:raw)PushCore(c);
  } else PushCore(key);
}
std::wstring Composer::Push(wchar_t key) {
  if(pending_escape_) {
    auto candidate=*pending_escape_+key;
    pending_escape_.reset();
    if(options_.smart_english && lexicon_ &&
       lexicon_->HasEnglishPrefix(candidate) &&
       !lexicon_->PreferVietnamesePrefix(candidate)) {
      raw_=candidate;text_=candidate;literal_=foreign_=shaped_=last_telex_=false;
      english_candidate_=true;
      return text_;
    }
  }
  bool repeated=!raw_.empty() && Lower(raw_.back())==Lower(key);
  bool short_escape=raw_.size()==2 && repeated &&
      Contains(L"sfrxj",Lower(key)) && Contains(L"aeiouy",Lower(raw_[0]));
  if(repeated && !literal_ && (last_telex_ || short_escape)) {
    pending_escape_=raw_+key;
    text_=raw_;literal_=true;
    english_candidate_=foreign_=shaped_=last_telex_=false;
    return text_;
  }
  auto prior=text_;
  const bool tone_now=!options_.vni && !literal_ && !foreign_ &&
                      ImmediateTone(raw_,key);
  if(!options_.vni && !literal_ && last_tone_ && raw_.size()>=3 &&
     Contains(L"aeo",Lower(key)) && Lower(raw_[raw_.size()-2])==Lower(key)) {
    auto vowels=Vowels(text_);
    if(vowels.size()>=2) {
      int i=vowels.back();
      wchar_t k=Lower(key);
      if(Base(text_[i])==k) {
        auto letters=text_;
        letters[i]=Shape(letters[i],k==L'a'?L'â':k==L'e'?L'ê':L'ô');
        auto candidate=Normalize(std::move(letters));
        if(LooksVietnamese(candidate)) {
          raw_+=key;text_=candidate;shaped_=true;
          english_candidate_=last_tone_=false;last_telex_=true;
          return text_;
        }
      }
    }
  }
  auto extended=Normalize(text_+key);
  bool after_tone=!options_.vni && !literal_ && last_tone_ &&
                  VowelAfterTone(raw_,key) && !LooksVietnamese(extended);
  raw_+=key;last_telex_=last_tone_=false;
  // Protect recognized English words whose double 'oo' token has a coda
  // impossible in Vietnamese (boost, book). Do NOT blindly protect 'soon':
  // that would corrupt a legitimate longer Telex word 'soong' -> 'sông'.
  // 'been' remains Vietnamese-priority ('bên') in Balanced mode.
  if(options_.smart_english && !options_.vni && lexicon_ &&
     raw_.size()>=4 && raw_.find(L"oo")!=std::wstring::npos &&
     ImpossibleVietnamese(raw_) && lexicon_->IsEnglishWord(raw_) &&
     !lexicon_->PreferVietnamesePrefix(raw_)) {
    text_=raw_;literal_=true;
    english_candidate_=foreign_=shaped_=false;
    return text_;
  }
  if(options_.english_first && options_.smart_english && !options_.vni &&
     lexicon_ && lexicon_->IsKnownEnglishWord(raw_)) {
    text_=raw_;english_candidate_=true;shaped_=foreign_=false;
    return text_;
  }
  if(after_tone) {
    literal_=true;foreign_=english_candidate_=shaped_=false;
    pending_escape_.reset();text_=raw_;return text_;
  }
  bool shape_now=!options_.vni && !literal_ &&
                 (ImmediateShape(raw_) || ImmediateW(prior,key));
  auto action=Classify(shape_now,tone_now);
  if(action==PrefixAction::PreserveForeign) {
    foreign_=true;english_candidate_=shaped_=false;text_=raw_;return text_;
  }
  if(action==PrefixAction::ProtectEnglish) {
    english_candidate_=true;shaped_=false;text_=raw_;return text_;
  }
  ApplyComposition(key);
  last_telex_=text_!=prior+key && !literal_;
  if((shape_now||tone_now) && text_!=raw_)shaped_=true;
  last_tone_=tone_now && text_!=raw_;
  if(MustRecoverInvalid()) {
    foreign_=true;shaped_=false;text_=raw_;return text_;
  }
  return text_;
}
std::wstring Composer::PushCore(wchar_t key) {
  if(text_.size()>=64)literal_=true;
  if(literal_)return text_+=key;
  return options_.vni?PushVni(key):PushTelex(key);
}
std::wstring Composer::PushTelex(wchar_t key) {
  wchar_t k=Lower(key);
  auto tone=std::wstring_view(L"zsfrxj").find(k);
  if(tone!=std::wstring_view::npos && !Vowels(text_).empty()) {
    int current=0;
    for(auto c:text_)if(Tone(c))current=Tone(c);
    if(tone==0) {
      if(current!=0)return text_=SetTone(text_,0);
    } else {
      if(current==static_cast<int>(tone))
        return Literal(SetTone(text_,0)+key);
      return text_=SetTone(text_,static_cast<int>(tone));
    }
  }
  auto letters=text_;
  if(k==L'd' && !letters.empty()) {
    for(auto& c:letters) {
      if(Lower(c)==L'd') {c=Case(L'đ',c);return text_=letters;}
      if(Lower(c)==L'đ') {c=Case(L'd',c);return Literal(letters+key);}
    }
  }
  auto vowels=Vowels(text_);
  if(Contains(L"aeo",k)) {
    const wchar_t target=k==L'a'?L'â':k==L'e'?L'ê':L'ô';
    for(int n=static_cast<int>(vowels.size())-1;n>=0;--n) {
      int i=vowels[n];auto b=Base(letters[i]);
      if(b==k){letters[i]=Shape(letters[i],target);return text_=Normalize(letters);}
      if(b==target){letters[i]=Shape(letters[i],k);return Literal(Normalize(letters)+key);}
    }
  }
  if(k==L'w' && text_.empty())return text_=std::wstring(1,Case(L'ư',key));
  if(k==L'w' && !vowels.empty()) {
    for(int n=static_cast<int>(vowels.size())-1;n>0;--n) {
      int i=vowels[n-1],j=vowels[n];
      if(j==i+1 && Contains(L"uư",Base(letters[i])) &&
         Contains(L"oôơ",Base(letters[j]))) {
        bool undo=Base(letters[i])==L'ư' && Base(letters[j])==L'ơ';
        letters[i]=Shape(letters[i],undo?L'u':L'ư');
        letters[j]=Shape(letters[j],undo?L'o':L'ơ');
        return undo?Literal(Normalize(letters)+key):text_=Normalize(letters);
      }
    }
    for(int n=static_cast<int>(vowels.size())-1;n>=0;--n) {
      int i=vowels[n],index=-1;
      auto p=std::wstring_view(L"auoăươ").find(Base(letters[i]));
      if(p==std::wstring_view::npos)continue;
      index=static_cast<int>(p);
      letters[i]=Shape(letters[i],L"ăươauo"[index]);
      return index>=3?Literal(Normalize(letters)+key):text_=Normalize(letters);
    }
  }
  return text_=Normalize(text_+key);
}
std::wstring Composer::PushVni(wchar_t key) {
  wchar_t k=Lower(key);
  if(k>=L'1' && k<=L'9' && !ImpossibleVietnamese(text_)) {
    if(k==L'9') {
      auto letters=text_;
      for(auto& c:letters)if(Lower(c)==L'd') {
        c=Case(L'đ',c);
        return text_=letters;
      }
      return text_+=key;
    }
    auto vowels=Vowels(text_);
    if(Contains(L"12345",k) && !vowels.empty())
      return text_=SetTone(text_,static_cast<int>(k-L'1'+1));
    if(k==L'6'||k==L'7'||k==L'8') {
      auto letters=text_;
      if(k==L'7' && vowels.size()>=2) {
        int i=vowels[vowels.size()-2],j=vowels.back();
        if(j==i+1 && Contains(L"uư",Base(letters[i])) &&
           Contains(L"oôơ",Base(letters[j]))) {
          letters[i]=Shape(letters[i],L'ư');
          letters[j]=Shape(letters[j],L'ơ');
          return text_=Normalize(letters);
        }
      }
      for(int n=static_cast<int>(vowels.size())-1;n>=0;--n) {
        int i=vowels[n];wchar_t b=Base(letters[i]);
        if(k==L'6' && Contains(L"aeo",b)) {
          letters[i]=Shape(letters[i],b==L'a'?L'â':b==L'e'?L'ê':L'ô');
          return text_=Normalize(letters);
        }
        if(k==L'7' && Contains(L"uo",b)) {
          letters[i]=Shape(letters[i],b==L'u'?L'ư':L'ơ');
          return text_=Normalize(letters);
        }
        if(k==L'8' && b==L'a') {
          letters[i]=Shape(letters[i],L'ă');return text_=Normalize(letters);
        }
      }
      return text_+=key;
    }
  }
  return text_=Normalize(text_+key);
}
std::wstring Composer::Finish() const {
  if(options_.smart_english && options_.english_first && !options_.vni &&
     lexicon_ && lexicon_->IsKnownEnglishWord(raw_))return raw_;
  if(pending_escape_ && options_.smart_english && lexicon_ &&
     lexicon_->IsEnglishWord(*pending_escape_))return *pending_escape_;
  if(options_.smart_english && !options_.vni && !literal_ &&
     (foreign_ || (lexicon_ && lexicon_->IsEnglishWord(raw_) &&
                    !(shaped_ && LooksVietnamese(text_) && !options_.english_first))))
    return raw_;
  if(english_candidate_) {
    Composer replay(lexicon_);
    auto opts=options_;opts.smart_english=false;
    replay.Configure(opts);
    for(auto c:raw_)replay.Push(c);
    return replay.Finish();
  }
  if(!options_.restore_invalid || literal_ || raw_==text_ || raw_.empty())return text_;
  for(auto c:raw_)if(c>127)return text_;
  return LooksVietnamese(text_)?text_:raw_;
}
EditPlan EditPlan::Between(std::wstring_view before,std::wstring_view after) {
  size_t common=0;
  while(common<before.size() && common<after.size() && before[common]==after[common])
    ++common;
  if(common>0 && before[common-1]>=0xD800 && before[common-1]<=0xDBFF)--common;
  return {static_cast<int>(before.size()-common),std::wstring(after.substr(common))};
}
}  // namespace telexmini
