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

/// C++ std lib declerations referrenced by RE2.
module re2d.stdcpp;

import core.stdc.config : cpp_ulong;
import core.stdcpp.allocator : allocator;
import core.stdcpp.xutility : StdNamespace;

extern (C++, (StdNamespace)):
@nogc package:

version (DigitalMars) {
  // TODO(karita): fix dmd to include core.stdcpp.utility.
  // https://issues.dlang.org/show_bug.cgi?id=22179
  struct pair(T1, T2) {
    ///
    alias first_type = T1;
    ///
    alias second_type = T2;

    ///
    T1 first;
    ///
    T2 second;

    // FreeBSD has pair as non-POD so add a contructor
    version (FreeBSD) {
      this(T1 t1, T2 t2) inout {
        first  = t1;
        second = t2;
      }
      this(ref return scope inout pair!(T1, T2) src) inout {
        first  = src.first;
        second = src.second;
      }
    }
  }
}
else {
  public import core.stdcpp.utility : pair;
}

struct less(T) {
  bool opCall()(const auto ref return scope T x, const auto ref return scope T y) const {
    return x < y;
  }
}

extern (C++, class) struct map(Key, T, Compare, Allocator);
alias map(Key, T) = map!(Key, T, less!Key, allocator!(pair!(Key, T)));

struct once_flag {
 private:
  version (CppRuntime_Microsoft) {
    static assert(false, "TODO");
  }
  else {
    cpp_ulong __state_ = 0;
  }
}
