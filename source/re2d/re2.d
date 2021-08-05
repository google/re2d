module re2d.re2;

import core.stdcpp.string : basic_string;

import re2d.stdcpp : once_flag, map;
import re2d.stringpiece : StringPiece;
static import re2d.internal;

extern (C++, "re2"):

extern (C++, class) struct Prog;
extern (C++, class) struct Regexp;

// Interface for regular expression matching.  Also corresponds to a
// pre-compiled regular expression.  An "RE2" object is safe for
// concurrent use by multiple threads.
extern (C++, class) struct RE2 {
 public:

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

  // Predefined common options.
  // If you need more complicated things, instantiate
  // an Option class, possibly passing one of these to
  // the Option constructor, change the settings, and pass that
  // Option class to the RE2 constructor.
  enum CannedOptions {
    DefaultOptions = 0,
    Latin1, // treat input as Latin-1 (default UTF-8)
    POSIX, // POSIX syntax, leftmost-longest match
    Quiet // do not log about regexp parse errors
  };

  this(const(char)* pattern) @nogc nothrow pure;
  this(const ref basic_string!char pattern) @nogc nothrow pure;
  this(const ref StringPiece pattern) @nogc nothrow pure;
  this(const ref StringPiece pattern, const ref Options options) @nogc nothrow pure;

  extern(D)
  this(string s) @nogc nothrow pure {
    const StringPiece sp = s;
    this(sp);
  }

  ~this() @nogc nothrow pure;
  @disable this(this);

  // Returns whether RE2 was created properly.
  bool ok() const @nogc nothrow pure { return error_code() == ErrorCode.NoError; }

  // The string specification for this RE2.  E.g.
  //   RE2 re("ab*c?d+");
  //   re.pattern();    // "ab*c?d+"
  const(char)[] pattern() const @nogc nothrow pure { return pattern_.as_array(); }

  // If RE2 could not be created properly, returns an error string.
  // Else returns the empty string.
  const(char)[] error() const @nogc nothrow pure { return error_.as_array(); }

  // If RE2 could not be created properly, returns an error code.
  // Else returns RE2::NoError (== 0).
  ErrorCode error_code() const @nogc nothrow pure { return error_code_; }

  // If RE2 could not be created properly, returns the offending
  // portion of the regexp.
  const(char)[] error_arg() const @nogc nothrow pure { return error_arg_.as_array(); }

  /// Test RE2 errors.
  version (re2d_test) @nogc nothrow pure unittest {
    RE2.Options opt;
    opt.log_errors = false;
    StringPiece s = `(\d`;
    auto re = RE2(s, opt);
    assert(!re.ok);
    assert(re.error == `missing ): (\d`);
    assert(re.error_code == RE2.ErrorCode.ErrorMissingParen);
    assert(re.error_arg == `(\d`);
  }

  // Returns the program size, a very approximate measure of a regexp's "cost".
  // Larger numbers are more expensive than smaller numbers.
  int ProgramSize() const @nogc nothrow pure;
  int ReverseProgramSize() const @nogc nothrow pure;

  version (re2d_test) @nogc nothrow pure unittest {
    RE2 pattern = "h.*o";
    assert(pattern.ok);
    assert(pattern.pattern == "h.*o");
    assert(pattern.ProgramSize == 14);
    assert(pattern.ReverseProgramSize == 14);
  }

  // TODO(karita): Support these funcs if stdcpp.vector is ready.
  // // If histogram is not null, outputs the program fanout
  // // as a histogram bucketed by powers of 2.
  // // Returns the number of the largest non-empty bucket.
  // int ProgramFanout(std::vector<int>* histogram) const;
  // int ReverseProgramFanout(std::vector<int>* histogram) const;

  // Returns the underlying Regexp; not for general use.
  // Returns entire_regexp_ so that callers don't need
  // to know about prefix_ and prefix_foldcase_.
  const(Regexp)* regexp() const @nogc nothrow pure { return entire_regexp_; }

  version (re2d_test) @nogc nothrow pure unittest {
    RE2 pattern = "h.*o";
    assert(pattern.regexp);
  }

  /***** The array-based matching interface ******/

  // The functions here have names ending in 'N' and are used to implement
  // the functions whose names are the prefix before the 'N'. It is sometimes
  // useful to invoke them directly, but the syntax is awkward, so the 'N'-less
  // versions should be preferred.
  static bool FullMatchN(const ref StringPiece text, const ref RE2 re,
                         const(Arg*)* args, int n) @nogc nothrow pure;
  static bool PartialMatchN(const ref StringPiece text, const ref RE2 re,
                            const(Arg*)* args, int n) @nogc nothrow pure;
  static bool ConsumeN(StringPiece* input, const ref RE2 re,
                       const(Arg*)* args, int n) @nogc nothrow pure;
  static bool FindAndConsumeN(StringPiece* input, const ref RE2 re,
                              const(Arg*)* args, int n) @nogc nothrow pure;

  /// Converts variadic arguments into Args[].
  extern (D)
  private static bool Apply(alias F, S, A...)(S s, string rs, A a) {
    auto re = RE2(rs);
    return Apply!F(s, re, a);
  }

  /// ditto.
  extern (D)
  private static bool Apply(alias F, SP, A...)(SP s, const ref RE2 re, A a) {
    static if (is(SP : string)) {
      StringPiece sp = s;
    }
    else {
      auto sp = s;
    }
    static if (A.length == 0) {
      return F(sp, re, null, 0);
    }
    else {
      Arg[A.length] args;
      Arg*[A.length] ptrs;
      static foreach (i; 0 .. A.length) {
        args[i] = Arg(a[i]);
        ptrs[i] = &args[i];
      }
      return F(sp, re, &ptrs[0], cast(int) A.length);
    }
  }

  // In order to allow FullMatch() et al. to be called with a varying number
  // of arguments of varying types, we use two layers of variadic templates.
  // The first layer constructs the temporary Arg objects. The second layer
  // (above) constructs the array of pointers to the temporary Arg objects.

  /***** The useful part: the matching interface *****/

  /// Matches "text" against "re".  If pointer arguments are
  /// supplied, copies matched sub-patterns into them.
  extern (D)
  static bool FullMatch(S, R, A...)(S text, const auto ref R re, A a) {
    return Apply!FullMatchN(text, re, a);
  }

  /// Like FullMatch(), except that "re" is allowed to match a substring
  /// of "text".
  extern (D)
  static bool PartialMatch(S, R, A...)(S text, const auto ref R re, A a) {
    return Apply!PartialMatchN(text, re, a);
  }

  // Like FullMatch() and PartialMatch(), except that "re" has to match
  // a prefix of the text, and "input" is advanced past the matched text.
  extern (D)
  static bool Consume(R, A...)(StringPiece* input, const auto ref R re, A a) {
    return Apply!ConsumeN(input, re, a);
  }

  // Like Consume(), but does not anchor the match at the beginning of
  // the text.  That is, "re" need not start its match at the beginning of "input".
  extern (D)
  static bool FindAndConsume(R, A...)(StringPiece* input, const auto ref R re, A a) {
    return Apply!FindAndConsumeN(input, re, a);
  }

  // Replace the first match of "re" in "str" with "rewrite".
  // Within "rewrite", backslash-escaped digits (\1 to \9) can be
  // used to insert text matching corresponding parenthesized group
  // from the pattern.  \0 in "rewrite" refers to the entire matching
  // text.
  // Returns true if the pattern matches and a replacement occurs,
  // false otherwise.
  static bool Replace(basic_string!(char)* str,
                      const ref RE2 re,
                      const ref StringPiece rewrite) @nogc nothrow pure;
  ///
  version (re2d_test) unittest {
    basic_string!char s = "yabba dabba doo";
    RE2 re = "b+";
    StringPiece rewrite = "d";
    assert(RE2.Replace(&s, re, rewrite));
    assert(s.as_array == "yada dabba doo");
  }

  // Like Replace(), except replaces successive non-overlapping occurrences
  // of the pattern in the string with the rewrite.
  // Returns the number of replacements made.
  static int GlobalReplace(basic_string!char* str,
                           const ref RE2 re,
                           const ref StringPiece rewrite);
  ///
  version (re2d_test) unittest {
    basic_string!char s = "yabba dabba doo";
    RE2 re = "b+";
    StringPiece rewrite = "d";
    assert(RE2.GlobalReplace(&s, re, rewrite) == 2);
    assert(s.as_array == "yada dada doo");
  }

  // Like Replace, except that if the pattern matches, "rewrite"
  // is copied into "out" with substitutions.  The non-matching
  // portions of "text" are ignored.
  //
  // Returns true iff a match occurred and the extraction happened
  // successfully;  if no match occurs, the string is left unaffected.
  //
  // REQUIRES: "text" must not alias any part of "*out".
  static bool Extract(const ref StringPiece text,
                      const ref RE2 re,
                      const ref StringPiece rewrite,
                      basic_string!char* outStr);
  ///
  version (re2d_test) unittest {
    StringPiece text = "yabba dabba doo";
    basic_string!char os = "";
    RE2 re = "b+";
    StringPiece rewrite = "d";
    assert(RE2.Extract(text, re, rewrite, &os));
    assert(os.toString == "d");
  }

  /// Escapes all potentially meaningful regexp characters in
  /// 'unquoted'.  The returned string, used as a regular expression,
  /// will match exactly the original string.
  // static basic_string!char QuoteMeta(const ref StringPiece unquoted);
  version (linux) {
    // TODO(karita): Fix this mangle name in Linux (OK in OSX).
    pragma(mangle, "_ZN3re23RE29QuoteMetaB5cxx11ERKNS_11StringPieceE")
    static basic_string!char QuoteMeta(const ref StringPiece unquoted);
  } else {
    static basic_string!char QuoteMeta(const ref StringPiece unquoted);
  }
  ///
  version (re2d_test) unittest {
    StringPiece s = "1.5-2.0?";
    auto quoted = QuoteMeta(s);
    // assert(QuoteMeta(s).as_array == `1\.5\-2\.0\?`);
  }

  /// Computes range for any strings matching regexp. The min and max can in
  /// some cases be arbitrarily precise, so the caller gets to specify the
  /// maximum desired length of string returned.
  ///
  /// Assuming PossibleMatchRange(&min, &max, N) returns successfully, any
  /// string s that is an anchored match for this regexp satisfies
  ///   min <= s && s <= max.
  ///
  /// Note that PossibleMatchRange() will only consider the first copy of an
  /// infinitely repeated element (i.e., any regexp element followed by a '*' or
  /// '+' operator). Regexps with "{N}" constructions are not affected, as those
  /// do not compile down to infinite repetitions.
  ///
  /// Returns true on success, false on error.
  bool PossibleMatchRange(basic_string!char* min, basic_string!char* max,
                          int maxlen) const;
  /// From re2/testing/possible_match_test.cc
  version (re2d_test) unittest {
    RE2 re = "(abc)+";
    basic_string!char min = "";
    basic_string!char max = "";
    assert(re.PossibleMatchRange(&min, &max, 5));
    assert(min.toString == "abc");
    assert(max.toString == "abcac");
  }

  // TODO(karita): Generic matching interface

  /// Type of match.
  enum Anchor {
    UNANCHORED,         // No anchoring
    ANCHOR_START,       // Anchor at start only
    ANCHOR_BOTH         // Anchor at start and end
  };

  /// Return the number of capturing subpatterns, or -1 if the
  /// regexp wasn't valid on construction.  The overall match ($0)
  /// does not count: if the regexp is "(a)(b)", returns 2.
  int NumberOfCapturingGroups() const { return num_captures_; }
  ///
  version (re2d_test) unittest {
    RE2 re = "(a)(b)";
    assert(re.NumberOfCapturingGroups == 2);
  }

  // TODO(karita): wrap this func when std::map is ready.
  // Return a map from names to capturing indices.
  // The map records the index of the leftmost group
  // with the given name.
  // Only valid until the re is deleted.
  // const std::map<std::string, int>& NamedCapturingGroups() const;

  // TODO(karita): wrap this func when std::map is ready.
  // Return a map from capturing indices to names.
  // The map has no entries for unnamed groups.
  // Only valid until the re is deleted.
  // const std::map<int, std::string>& CapturingGroupNames() const;

  /// We convert user-passed pointers into special Arg objects.
  extern (C++, class) struct Arg {
   public:
    @nogc nothrow pure:
    alias Parser = bool function(const(char)* str, size_t n, const(void*) arg);

    this(typeof(null)) {}

    this(Arg a) {
      arg_ = a.arg_;
      parser_ = a.parser_;
    }

    this(T)(T* ptr, Parser parser) {
      arg_ = ptr;
      parser_ = parser;
    }

    this(T)(T* ptr) if (re2d.internal.canParse3ary!T) {
      this(ptr, &(DoParse3ary!T));
    }

    this(T)(T* ptr) if (re2d.internal.canParse4ary!T) {
      this(ptr, &(DoParse4ary!T));
    }

    bool Parse(const(char)* str, size_t n) const {
      return parser_(str, n, arg_);
    }

   private:
    static bool DoNothing(const(char)* str, size_t n, const(void*) arg) {
      return true;
    }

    static bool DoParse3ary(T)(const(char)* str, size_t n, const(void)* dest) {
      return re2d.internal.Parse(str, n, cast(T*) dest);
    }

    static bool DoParse4ary(T)(const(char)* str, size_t n, const(void)* dest) {
      return re2d.internal.Parse(str, n, cast(T*) dest, 10);
    }

    // TODO(karita): DoParseFrom.

    void* arg_ = null;
    Parser parser_ = &DoNothing;
  }

  /// Constructor options
  extern (C++, class) struct Options {
    @nogc nothrow pure:
   public:
    // The options are (defaults in parentheses):
    //
    //   utf8             (true)  text and pattern are UTF-8; otherwise Latin-1
    //   posix_syntax     (false) restrict regexps to POSIX egrep syntax
    //   longest_match    (false) search for longest match, not first match
    //   log_errors       (true)  log syntax and execution errors to ERROR
    //   max_mem          (see below)  approx. max memory footprint of RE2
    //   literal          (false) interpret string as literal, not regexp
    //   never_nl         (false) never match \n, even if it is in regexp
    //   dot_nl           (false) dot matches everything including new line
    //   never_capture    (false) parse all parens as non-capturing
    //   case_sensitive   (true)  match is case-sensitive (regexp can override
    //                              with (?i) unless in posix_syntax mode)
    //
    // The following options are only consulted when posix_syntax == true.
    // When posix_syntax == false, these features are always enabled and
    // cannot be turned off; to perform multi-line matching in that case,
    // begin the regexp with (?m).
    //   perl_classes     (false) allow Perl's \d \s \w \D \S \W
    //   word_boundary    (false) allow Perl's \b \B (word boundary and not)
    //   one_line         (false) ^ and $ only match beginning and end of text
    //
    // The max_mem option controls how much memory can be used
    // to hold the compiled form of the regexp (the Prog) and
    // its cached DFA graphs.  Code Search placed limits on the number
    // of Prog instructions and DFA states: 10,000 for both.
    // In RE2, those limits would translate to about 240 KB per Prog
    // and perhaps 2.5 MB per DFA (DFA state sizes vary by regexp; RE2 does a
    // better job of keeping them small than Code Search did).
    // Each RE2 has two Progs (one forward, one reverse), and each Prog
    // can have two DFAs (one first match, one longest match).
    // That makes 4 DFAs:
    //
    //   forward, first-match    - used for UNANCHORED or ANCHOR_START searches
    //                               if opt.longest_match() == false
    //   forward, longest-match  - used for all ANCHOR_BOTH searches,
    //                               and the other two kinds if
    //                               opt.longest_match() == true
    //   reverse, first-match    - never used
    //   reverse, longest-match  - used as second phase for unanchored searches
    //
    // The RE2 memory budget is statically divided between the two
    // Progs and then the DFAs: two thirds to the forward Prog
    // and one third to the reverse Prog.  The forward Prog gives half
    // of what it has left over to each of its DFAs.  The reverse Prog
    // gives it all to its longest-match DFA.
    //
    // Once a DFA fills its budget, it flushes its cache and starts over.
    // If this happens too often, RE2 falls back on the NFA implementation.

    // For now, make the default budget something close to Code Search.
    enum int kDefaultMaxMem = 8<<20;

    enum Encoding {
      EncodingUTF8 = 1,
      EncodingLatin1
    }

    this(CannedOptions);
    int ParseFlags() const;

    Encoding encoding = Encoding.EncodingUTF8;
    bool posix_syntax = false;
    bool longest_match = false;
    bool log_errors = true;
    long max_mem = kDefaultMaxMem;
    bool literal = false;
    bool never_nl = false;
    bool dot_nl = false;
    bool never_capture = false;
    bool case_sensitive = true;
    bool perl_classes = false;
    bool word_boundary = false;
    bool one_line = false;
  }

  /// Returns the options set in the constructor.
  ref const(Options) options() return const { return options_; }

  // Argument converters; see below.
  static Arg CRadix(T)(T* ptr) {
    return Arg(ptr, &(re2d.internal.ParseVoidPtr!(T, 0)));
  }
  static Arg Hex(T)(T* ptr) {
    return Arg(ptr, &(re2d.internal.ParseVoidPtr!(T, 16)));
  }
  static Arg Octal(T)(T* ptr) {
    return Arg(ptr, &(re2d.internal.ParseVoidPtr!(T, 8)));
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


version (re2d_test) @nogc nothrow pure:

/// Test data size in RE2.
version (OSX) version (AArch64)
unittest {
  assert(RE2.ErrorCode.sizeof == 4);
  assert(RE2.Arg.sizeof == 16);
  assert(RE2.Options.sizeof == 24);
  assert(RE2.sizeof == 200);
}

/// Test FullMatchN without args.
unittest {
  auto text = StringPiece("hello");
  auto pattern = RE2("h.*o");
  assert(RE2.FullMatchN(text, pattern, null, 0));

  auto pattern2 = RE2("e");
  assert(!RE2.FullMatchN(text, pattern2, null, 0));
}

/// Test FullMatchN with args.
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

/// Test FullMatch examples.
unittest {
  assert(RE2.FullMatch("hello", "h.*o"));
  assert(!RE2.FullMatch("hello", "e"));

  // Default UTF-8 support enabled.
  int i;
  StringPiece s;
  assert(RE2.FullMatch("ルビー:1234", "([^:]+):(\\d+)", &s, &i));
  assert(s.toString == "ルビー");
  assert(i == 1234);

  // Example: extracts "ruby" into "s" and 1234 into "i"
  // RE2 also supports Latin-1 input mode.
  StringPiece ps = "(\\w+):(\\d+)";
  RE2.Options opt = RE2.CannedOptions.Latin1;
  auto re = RE2(ps, opt);
  assert(RE2.FullMatch("ruby:1234", re, &s, &i));
  assert(s.toString == "ruby");
  assert(i == 1234);

  // Example: fails because string cannot be stored in integer
  assert(!RE2.FullMatch("ruby", "(.*)", &i));

  // Example: fails because there aren't enough sub-patterns
  assert(!RE2.FullMatch("ruby:1234", "\\w+:\\d+", &s));

  // Example: does not try to extract any extra sub-patterns
  assert(RE2.FullMatch("ruby:1234", "(\\w+):(\\d+)", &s));

  // Example: does not try to extract into NULL
  assert(RE2.FullMatch("ruby:1234", "(\\w+):(\\d+)", null, &i));

  // Example: integer overflow causes failure
  assert(!RE2.FullMatch("ruby:1234567891234", "\\w+:(\\d+)", &i));
  // but float can store it.
  float f;
  assert(RE2.FullMatch("ruby:1234567891234", "\\w+:(\\d+)", &f));
}

/// Test partial matches.
unittest {
  assert(RE2.PartialMatch("hello", "ell"));
  assert(!RE2.PartialMatch("hello", "all"));

  int number;
  assert(RE2.PartialMatch("x*100 + 20", `(\d+)`, &number));
  assert(number == 100);

  StringPiece s;
  assert(RE2.PartialMatch("x*100 + 20", `(\w+)`, &s));
  assert(s.toString == "x");
}

/// Test scanning text incrementally by Consume.
unittest {
  StringPiece input = `foo = 1
bar = 2
`;
  StringPiece var;
  int value;
  RE2 re = `(\w+) = (\d)\n`;
  assert(RE2.Consume(&input, re, &var, &value));
  assert(var.toString == "foo");
  assert(value == 1);
  assert(RE2.Consume(&input, re, &var, &value));
  assert(var.toString == "bar");
  assert(value == 2);
  assert(!RE2.Consume(&input, re, &var, &value));
}

/// Test scanning text incrementally with anchor match by FindAndConsume.
unittest {
  StringPiece input = "(foo bar)";
  RE2 re = `(\w+)`;
  StringPiece word;
  assert(RE2.FindAndConsume(&input, re, &word));
  assert(word.toString == "foo");
  assert(RE2.FindAndConsume(&input, re, &word));
  assert(word.toString == "bar");
  assert(!RE2.FindAndConsume(&input, re, &word));
}

/// Test using variable number of arguments.
unittest {
  StringPiece s;
  int i;
  auto as = RE2.Arg(&s);
  auto ai = RE2.Arg(&i);
  RE2.Arg*[2] args;
  args[0] = &as;
  args[1] = &ai;
  RE2.FullMatch("ruby:1234", `(\w+):(\d+)`, *args[0], *args[1]);
  assert(s.toString == "ruby");
  assert(i == 1234);
}

/// Test parsing hex/octal/c-radix numbers.
unittest {
  int a, b, c, d;
  assert(RE2.FullMatch("100 40 0100 0x40", "(.*) (.*) (.*) (.*)",
                       RE2.Octal(&a), RE2.Hex(&b), RE2.CRadix(&c), RE2.CRadix(&d)));
  assert(a == 8 * 8);
  assert(b == 4 * 16);
  assert(c == 8 * 8);
  assert(c == 0x40);
}

// TODO(karita): Test multi thread usage.
