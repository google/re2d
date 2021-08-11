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
module re2d.stringpiece;

import core.stdc.string : strlen;

extern (C++, "re2"):

extern (C++, class) struct StringPiece {
 public:
  @nogc nothrow pure:
  alias const_pointer = const(char)*;
  alias size_type = size_t;
  enum npos = cast(size_t) -1;

  @safe
  this(const(char)* str, size_type len) {
    data_ = str;
    size_ = len;
  }

  this(const(char)* str) {
    this(str, strlen(str));
  }

  extern (D) @safe
  this(string str) {
    this(&str[0], str.length);
  }

  extern (D)
  const(char)[] toString() {
    return data_[0 .. size_];
  }

  alias toString this;

  size_type size() const { return size_; }
  const_pointer data() const { return data_; }

 private:
  const_pointer data_ = null;
  size_type size_ = 0;
}

version (re2d_test) @nogc nothrow pure unittest {
  StringPiece s = "hello";
  assert(s == "hello");
  assert(StringPiece(s.data_) == "hello");
}
