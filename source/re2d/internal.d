/// Implementation details on arg parser.
module re2d.internal;

import core.stdc.config : cpp_long, cpp_longlong, cpp_ulong, cpp_ulonglong;
import core.stdcpp.string : basic_string;

import re2d.stringpiece : StringPiece;

extern (C++, "re2"):
extern (C++, "re2_internal"):
@nogc nothrow pure:

bool Parse(T)(const(char)* str, size_t n, T* dest);

bool Parse(T)(const(char)* str, size_t n, T* dest, int radix);

bool ParseVoidPtr(T, int radix)(const(char)* str, size_t n, const(void*) dest) {
  return Parse(str, n, cast(T*) dest, radix);
}

enum bool canParse3ary(T) =
  is(T == void) ||
  is(T == basic_string!char) ||
  is(T == StringPiece) ||
  is(T == char) ||
  is(T == byte) ||
  is(T == ubyte) ||
  is(T == float) ||
  is(T == double);

version (re2d_test) unittest {
  assert(canParse3ary!float);
  assert(canParse3ary!StringPiece);
  assert(!canParse3ary!int);
}

enum bool canParse4ary(T) =
  is(T == long) ||
  is(T == cpp_long) ||
  is(T == ulong) ||
  is(T == cpp_ulong) ||
  is(T == short) ||
  is(T == ushort) ||
  is(T == int) ||
  is(T == uint) ||
  is(T == cpp_longlong) ||
  is(T == cpp_ulonglong);

version (re2d_test) unittest {
  assert(!canParse4ary!float);
  assert(!canParse4ary!StringPiece);
  assert(canParse4ary!int);
}

// TODO(karita): canParseFrom.
