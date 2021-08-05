module re2d.stringpiece;

import core.stdc.string : strlen;

extern (C++, "re2"):

extern (C++, class) struct StringPiece {
 public:
  @nogc nothrow pure:
  alias const_pointer = const(char)*;
  alias size_type = size_t;
  // static __gshared const size_type npos = cast(size_t) -1;

  this(const(char)* str, size_type len) {
    data_ = str;
    size_ = len;
  }

  this(const(char)* str) {
    this(str, strlen(str));
  }

  extern (D)
  this(string str) {
    this(&str[0], str.length);
  }

  extern (D)
  const(char)[] toString() {
    return data_[0 .. size_];
  }

 private:
  const_pointer data_ = null;
  size_type size_ = 0;
}

unittest {
  StringPiece s = "hello";
  assert(s.toString == "hello");
}
