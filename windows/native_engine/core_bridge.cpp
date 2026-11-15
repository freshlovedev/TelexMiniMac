#include "core.h"
#include <windows.h>
#include <filesystem>
#include <memory>
#include <new>
#include <string>

namespace {
struct RuntimeEngine {
  telexmini::Lexicon lexicon;
  telexmini::Composer composer{&lexicon};
  telexmini::ComposerOptions options;
  std::wstring seedPath,userEnglish,userVietnamese,finished;
  RuntimeEngine(std::wstring seed,std::wstring english,std::wstring vietnamese)
    :seedPath(std::move(seed)),userEnglish(std::move(english)),
     userVietnamese(std::move(vietnamese)) {
    Reload();
  }
  void Reload() {
    composer.Reset();
    lexicon=telexmini::Lexicon{};
    lexicon.LoadWordsFile(seedPath);
    lexicon.LoadWordsFile(userEnglish);
    lexicon.LoadWordsFile(userVietnamese,true);
    composer.Configure(options);
    finished.clear();
  }
};
}
extern "C" {
__declspec(dllexport) unsigned __cdecl TelexMiniEngine_ApiVersion() {return 1;}
__declspec(dllexport) RuntimeEngine* __cdecl TelexMiniEngine_Create(
    const wchar_t* seed,const wchar_t* english,const wchar_t* vietnamese) {
  try {
    return new RuntimeEngine(seed?seed:L"",english?english:L"",
                             vietnamese?vietnamese:L"");
  } catch(...) { return nullptr; }
}
__declspec(dllexport) void __cdecl TelexMiniEngine_Destroy(RuntimeEngine* engine) {
  delete engine;
}
__declspec(dllexport) bool __cdecl TelexMiniEngine_Configure(
    RuntimeEngine* engine,bool smart,bool prefer,bool vni,bool restore) {
  if(!engine)return false;
  engine->options={smart,prefer,vni,restore};
  engine->composer.Configure(engine->options);
  return true;
}
__declspec(dllexport) bool __cdecl TelexMiniEngine_Reload(RuntimeEngine* engine) {
  if(!engine)return false;
  try {engine->Reload();return true;}catch(...){return false;}
}
__declspec(dllexport) void __cdecl TelexMiniEngine_Reset(RuntimeEngine* engine) {
  if(engine)engine->composer.Reset();
}
__declspec(dllexport) void __cdecl TelexMiniEngine_Backspace(RuntimeEngine* engine) {
  if(engine)engine->composer.Backspace();
}
__declspec(dllexport) bool __cdecl TelexMiniEngine_Restore(
    RuntimeEngine* engine,const wchar_t* word) {
  if(!engine)return false;
  try {engine->composer.RestoreLiteralWord(word?word:L"");return true;}
  catch(...){return false;}
}
__declspec(dllexport) const wchar_t* __cdecl TelexMiniEngine_Text(
    RuntimeEngine* engine) {
  return engine?engine->composer.Text().c_str():nullptr;
}
__declspec(dllexport) const wchar_t* __cdecl TelexMiniEngine_Push(
    RuntimeEngine* engine,wchar_t key) {
  if(!engine)return nullptr;
  try {engine->composer.Push(key);return engine->composer.Text().c_str();}
  catch(...){return nullptr;}
}
__declspec(dllexport) const wchar_t* __cdecl TelexMiniEngine_Finish(
    RuntimeEngine* engine) {
  if(!engine)return nullptr;
  try {engine->finished=engine->composer.Finish();
       return engine->finished.c_str();}
  catch(...){return nullptr;}
}
__declspec(dllexport) unsigned __cdecl TelexMiniEngine_LexiconSize(
    RuntimeEngine* engine) {
  return engine?static_cast<unsigned>(engine->lexicon.WordCount()):0;
}
}
