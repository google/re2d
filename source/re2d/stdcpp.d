/// C++ std lib declerations referrenced by RE2.
module re2d.stdcpp;

import core.stdc.config : cpp_ulong;
import core.stdcpp.allocator : allocator;
import core.stdcpp.utility : pair;

extern (C++, "std"):

struct less(T) {
  bool opCall()(const auto ref T x, const auto ref T y) const {
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
