// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
