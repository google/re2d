module re2.re2;

import core.stdc.config : cpp_long, cpp_longlong, cpp_ulong, cpp_ulonglong;
import core.stdcpp.string : basic_string;

import re2.stdcpp : once_flag, map;
import re2.stringpiece : StringPiece;

enum bool canParse3ary(T) =
  is(T == void) ||
  is(T == basic_string!char) ||
  is(T == StringPiece) ||
  is(T == char) ||
  is(T == byte) ||
  is(T == ubyte) ||
  is(T == float) ||
  is(T == double);

unittest {
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

unittest {
  assert(!canParse4ary!float);
  assert(!canParse4ary!StringPiece);
  assert(canParse4ary!int);
}

extern (C++, "re2"):

extern (C++, "re2_internal")
bool Parse(T)(const(char)* str, size_t n, T* dest);

extern (C++, "re2_internal")
bool Parse(T)(const(char)* str, size_t n, T* dest, int radix);

extern (C++, class) struct Prog;
extern (C++, class) struct Regexp;

// Interface for regular expression matching.  Also corresponds to a
// pre-compiled regular expression.  An "RE2" object is safe for
// concurrent use by multiple threads.
extern (C++, class) struct RE2 {
 public:
  @nogc nothrow pure:

  enum ErrorCode {
    NoError = 0,

    // Unexpected error
    ErrorInternal,

    // Parse errors
    ErrorBadEscape,          // bad escape sequence
    ErrorBadCharClass,       // bad character class
    ErrorBadCharRange,       // bad character class range
    ErrorMissingBracket,     // missing closing ]
    ErrorMissingParen,       // missing closing )
    ErrorUnexpectedParen,    // unexpected closing )
    ErrorTrailingBackslash,  // trailing \ at end of regexp
    ErrorRepeatArgument,     // repeat argument missing, e.g. "*"
    ErrorRepeatSize,         // bad repetition argument
    ErrorRepeatOp,           // bad repetition operator
    ErrorBadPerlOp,          // bad perl operator
    ErrorBadUTF8,            // invalid UTF-8 in regexp
    ErrorBadNamedCapture,    // bad named capture group
    ErrorPatternTooLarge     // pattern too large (compile failed)
  }

  extern (C++, class) struct Arg {
   public:
    alias Parser = bool function(const(char)* str, size_t n, const(void*) arg);

    this(typeof(null)) {}

    this(T)(T* ptr) {
      arg_ = ptr;
      static if (canParse3ary!T) {
        parser_ = &(DoParse3ary!T);
      }
      else if (canParse4ary!T) {
        parser_ = &(DoParse4ary!T);
      }
      else {
        assert(false, "Cannot parse T.");
      }
    }

    static bool DoParse3ary(T)(const(char)* str, size_t n, const(void)* dest) {
      return Parse(str, n, cast(T*) dest);
    }

    static bool DoParse4ary(T)(const(char)* str, size_t n, const(void)* dest) {
      return Parse(str, n, cast(T*) dest, 10);
    }

   private:
    static bool DoNothing(const(char)* str, size_t n, const(void*) arg) {
      return true;
    }

    void* arg_ = null;
    Parser parser_ = &DoNothing;
  }

  extern (C++, class) struct Options {
   public:
    // For now, make the default budget something close to Code Search.
    // __gshared static const int kDefaultMaxMem = 8<<20;

    enum Encoding {
      EncodingUTF8 = 1,
      EncodingLatin1
    }

   private:
    Encoding encoding_;
    bool posix_syntax_;
    bool longest_match_;
    bool log_errors_;
    long max_mem_;
    bool literal_;
    bool never_nl_;
    bool dot_nl_;
    bool never_capture_;
    bool case_sensitive_;
    bool perl_classes_;
    bool word_boundary_;
    bool one_line_;
  }

  this(const(char)* pattern);
  this(const ref basic_string!char pattern);
  this(const ref StringPiece pattern);

  extern(D)
  this(string s) {
    const StringPiece sp = s;
    this(sp);
  }
  ~this();
  @disable this(this);

  /***** The array-based matching interface ******/

  // The functions here have names ending in 'N' and are used to implement
  // the functions whose names are the prefix before the 'N'. It is sometimes
  // useful to invoke them directly, but the syntax is awkward, so the 'N'-less
  // versions should be preferred.
  static bool FullMatchN(const ref StringPiece text, const ref RE2 re,
                         const(Arg*)* args, int n);
  static bool PartialMatchN(const ref StringPiece text, const ref RE2 re,
                            const(Arg*)* args, int n);
  static bool ConsumeN(StringPiece* input, const ref RE2 re,
                       const(Arg*)* args, int n);
  static bool FindAndConsumeN(StringPiece* input, const ref RE2 re,
                              const(Arg*)* args, int n);

  extern (D)
  static bool Apply(alias F, S, R, A...)(S s, R rs, A a) if (!is(R == RE2)) {
    auto re = RE2(rs);
    return Apply!F(s, re, a);
  }

  extern (D)
  static bool Apply(alias F, S, A...)(S s, const ref RE2 re, A a) {
    StringPiece sp = s;
    Arg[A.length] args;
    Arg*[A.length] ptrs;
    static foreach (i, x; a) {
      args[i] = Arg(a[i]);
      ptrs[i] = &args[i];
    }
    return F(sp, re, &ptrs[0], cast(int) A.length);
  }

  extern (D)
  static bool FullMatch(S, R, A...)(S s, const auto ref R re, A a) {
    return Apply!FullMatchN(s, re, a);
  }

  extern (D)
  static bool PartialMatch(S, R, A...)(S s, const auto ref R re, A a) {
    return Apply!PartialMatchN(s, re, a);
  }

  extern (D)
  static bool Consume(S, R, A...)(S s, const auto ref R re, A a) {
    return Apply!ConsumeN(s, re, a);
  }

  extern (D)
  static bool FindAndConsume(S, R, A...)(S s, const auto ref R re, A a) {
    return Apply!FindAndConsume(s, re, a);
  }

 private:
  basic_string!char pattern_;         // string regular expression
  Options options_;             // option flags
  Regexp* entire_regexp_;  // parsed regular expression
  const(basic_string!char)* error_;    // error indicator (or points to empty string)
  ErrorCode error_code_;        // error code
  basic_string!char error_arg_;       // fragment of regexp showing error
  basic_string!char prefix_;          // required prefix (before suffix_regexp_)
  bool prefix_foldcase_;        // prefix_ is ASCII case-insensitive
  Regexp* suffix_regexp_;  // parsed regular expression, prefix_ removed
  Prog* prog_;             // compiled program for regexp
  int num_captures_;            // number of capturing groups
  bool is_one_pass_;            // can use prog_->SearchOnePass?

  // Reverse Prog for DFA execution only
  Prog* rprog_;
  // Map from capture names to indices
  map!(basic_string!char, int)* named_groups_;
  // Map from capture indices to names
  map!(int, basic_string!char)* group_names_;

  once_flag rprog_once_;
  once_flag named_groups_once_;
  once_flag group_names_once_;
}

@nogc nothrow pure:

unittest {
  assert(RE2.ErrorCode.sizeof == 4);
  assert(RE2.Arg.sizeof == 16);
  assert(RE2.Options.sizeof == 24);
  assert(RE2.sizeof == 200);
}

unittest {
  auto text = StringPiece("hello");
  auto pattern = RE2("h.*o");
  assert(RE2.FullMatchN(text, pattern, null, 0));
}

unittest {
  auto text = StringPiece("hello");
  auto pattern = RE2("e");
  assert(!RE2.FullMatchN(text, pattern, null, 0));
}

unittest {
  int i;
  int j;
  auto ai = RE2.Arg(&i);
  auto aj = RE2.Arg(&j);
  const(RE2.Arg*)[2] args = [&ai, &aj];

  const input = StringPiece("123:1234");
  const pattern = RE2("(\\d+):(\\d+)");
  assert(RE2.FullMatchN(input, pattern, args.ptr, 2));
  assert(i == 123);
  assert(j == 1234);
}

unittest {
  int i;
  StringPiece s;
  auto as = RE2.Arg(&s);
  auto ai = RE2.Arg(&i);
  const(RE2.Arg*)[2] args = [&as, &ai];

  const input = StringPiece("ruby:1234");
  const pattern = RE2("(\\w+):(\\d+)");
  assert(RE2.FullMatchN(input, pattern, args.ptr, 2));
  assert(s.toString == "ruby");
  assert(i == 1234);
}

unittest {
  int i;
  StringPiece s;
  assert(RE2.FullMatch("ruby:1234", "(\\w+):(\\d+)", &s, &i));
  assert(s.toString == "ruby");
  assert(i == 1234);
}

unittest {
  int i;
  StringPiece s;
  assert(RE2.FullMatch("ルビー:1234", "([^:]+):(\\d+)", &s, &i));
  assert(s.toString == "ルビー");
  assert(i == 1234);
}
