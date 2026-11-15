#include "c_api.h"
#include <fstream>
#include <iostream>
#include <string>
#include <vector>
int main(int argc, char** argv) {
  if (argc != 3) { std::cerr << "usage: test_portable corpus.tsv english-core.txt\n"; return 2; }
  auto* t = tm_create(argv[2], "", "");
  if (!t) return 2;
  std::ifstream input(argv[1], std::ios::binary);
  if (!input) { std::cerr << "missing corpus\n"; return 2; }
  std::string line;
  int count = 0, failures = 0;
  while (std::getline(input, line)) {
    if (line.empty() || line[0] == '#' || line.rfind("raw\t", 0) == 0) continue;
    if (line.back() == '\r') line.pop_back();
    size_t one = line.find('\t'), two = line.find('\t', one + 1);
    if (one == line.npos || two == line.npos) continue;
    const auto typed = line.substr(0, one);
    const auto want = line.substr(one + 1, two - one - 1);
    const auto mode = line.substr(two + 1);
    tm_reset(t);
    tm_configure(t, 0, 0, mode == "vni", 1);
    for (unsigned char c : typed) tm_push(t, c);
    const char* end = tm_finish(t);
    const std::string result = end ? end : "";
    ++count;
    if (result != want) {
      if (failures < 12) std::cout << "FAIL " << typed << " got " << result << " expected " << want << "\n";
      ++failures;
    }
  }
  for (auto [raw, want] : std::vector<std::pair<std::string, std::string>>{
          {"w", "ư"}, {"now", "nơ"}, {"uow", "ươ"}, {"tieengs", "tiếng"},
          {"boons", "bốn"}, {"been", "bên"}, {"chayj", "chạy"},
          {"boost", "boost"}, {"booster", "booster"}, {"book", "book"},
          {"windows", "windows"}, {"parameter", "parameter"}, {"as", "á"},
          {"soong", "sông"}, {"soon", "sôn"}, {"room", "rôm"}, {"root", "rôt"}}) {
    tm_reset(t); tm_configure(t, 1, 0, 0, 1);
    for (unsigned char c : raw) tm_push(t, c);
    auto actual = std::string(tm_finish(t));
    ++count;
    if (actual != want) {
      if (failures < 12) std::cout << "FAIL " << raw << " got " << actual << " expected " << want << "\n";
      ++failures;
    }
  }
  std::cout << "PORTABLE_CORE cases=" << count << " failures=" << failures
            << " dictionaryWords=" << tm_dictionary_size(t) << "\n";
  tm_destroy(t);
  return failures ? 1 : 0;
}
