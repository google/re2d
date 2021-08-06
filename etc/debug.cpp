#include <iostream>
#include <re2/re2.h>

struct A {
};

int main() {
  int i;
  std::string s;
  std::cout << "size: " << sizeof(re2::StringPiece) << std::endl;
  std::cout << "size: " << sizeof(RE2::ErrorCode) << std::endl;
  std::cout << "size: " << sizeof(RE2::Options) << std::endl;
  std::cout << "size: " << sizeof(RE2::Arg) << std::endl;
  std::cout << "size: " << sizeof(RE2) << std::endl;
  if (RE2::FullMatch("ルビー:1234", "([^:]+):(\\d+)", &s, &i)) {
    std::cout << "Match: s=" << s << ", i=" << i << std::endl;
  }
  auto re = RE2("h.*o");
  std::cout << "ProgramSize:" << re.ProgramSize() << std::endl;
  std::cout << "ReverseProgramSize:" << re.ReverseProgramSize() << std::endl;
}
