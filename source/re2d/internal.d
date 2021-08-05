module re2d.internal;

extern (C++, "re2"):
extern (C++, "re2_internal"):
@nogc nothrow pure:

bool Parse(T)(const(char)* str, size_t n, T* dest);

bool Parse(T)(const(char)* str, size_t n, T* dest, int radix);

bool ParseVoidPtr(T, int radix)(const(char)* str, size_t n, const(void*) dest) {
  return Parse(str, n, cast(T*) dest, radix);
}
