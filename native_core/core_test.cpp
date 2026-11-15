#include "core.h"
#include <windows.h>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>
using namespace telexmini;
static std::wstring FromUtf8(const std::string& s) {
  if(s.empty())return {};
  int n=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,s.data(),static_cast<int>(s.size()),nullptr,0);
  if(!n)return {};
  std::wstring v(static_cast<size_t>(n),L'\0');
  MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,s.data(),static_cast<int>(s.size()),v.data(),n);
  return v;
}
static std::string ToUtf8(std::wstring_view v) {
  if(v.empty())return {};
  int n=WideCharToMultiByte(CP_UTF8,0,v.data(),static_cast<int>(v.size()),nullptr,0,nullptr,nullptr);
  std::string out(static_cast<size_t>(n),'\0');
  WideCharToMultiByte(CP_UTF8,0,v.data(),static_cast<int>(v.size()),out.data(),n,nullptr,nullptr);
  return out;
}
int wmain(int argc,wchar_t** argv) {
  if(argc<3){std::cerr<<"usage: core_tests fixtures english_seed [english_user] [vi_overrides]\n";return 2;}
  Lexicon words;
  if(!words.LoadWordsFile(argv[2])){std::cerr<<"Missing seed\n";return 2;}
  if(argc>=4)words.LoadWordsFile(argv[3]);
  if(argc>=5)words.LoadWordsFile(argv[4],true);
  std::ifstream fixture(argv[1],std::ios::binary);
  if(!fixture){std::cerr<<"Missing oracle fixtures\n";return 2;}
  std::string line;std::getline(fixture,line);
  int tests=0,failures=0,reported=0;
  while(std::getline(fixture,line)) {
    if(!line.empty() && line.back()=='\r')line.pop_back();
    if(line.empty())continue;
    auto t1=line.find('\t'),t2=line.find('\t',t1+1),t3=line.rfind('\t');
    if(t1==line.npos || t2==line.npos || t3==line.npos || t3<=t2)continue;
    auto mode=line.substr(0,t1);
    auto typed=FromUtf8(line.substr(t1+1,t2-t1-1));
    auto steps=FromUtf8(line.substr(t2+1,t3-t2-1));
    auto done=FromUtf8(line.substr(t3+1));
    ComposerOptions opts;
    opts.smart_english=mode=="balanced" || mode=="english";
    opts.english_first=mode=="english";opts.vni=mode=="vni";
    Composer composer(&words);composer.Configure(opts);
    std::wstring combined;
    for(auto c:typed) {
      if(!combined.empty())combined+=L'|';
      combined+=composer.Push(c);
    }
    auto finished=composer.Finish();
    tests++;
    if(combined!=steps || finished!=done) {
      failures++;
      if(reported++<20) {
        std::cout<<"FAIL mode="<<mode<<" typed="<<ToUtf8(typed)
                 <<" got="<<ToUtf8(combined)<<" expected="<<ToUtf8(steps)
                 <<" finish="<<ToUtf8(finished)<<" expectedEnd="<<ToUtf8(done)<<"\n";
      }
    }
  }
  std::cout<<"TSF_NATIVE_ORACLE cases="<<tests<<" failures="<<failures
           <<" dictionaryWords="<<words.WordCount()<<"\n";
  return failures==0?0:1;
}