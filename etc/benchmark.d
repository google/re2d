/+ dub.json:
{
  "dependencies": {
     "re2d": {"path": ".."}
  },
  "libs": ["re2", "c++"]
}
+/
// Benchmark with random string and EASY/MEDIUM/HARD regexps from RE2:
// https://github.com/google/re2/blob/2021-08-01/re2/testing/regexp_benchmark.cc
import core.stdc.stdlib : srand, rand;
import std.regex : ctRegex, matchAll, matchFirst, regex;
import std.datetime.stopwatch : benchmark;
import std.stdio;
import re2d;

// Generate random text that won't contain the search string,
// to test worst-case search behavior.
const(char)[] RandomText(int seed) {
  char[] text;
  srand(seed);
  text.length = 16<<20;
  for (long i = 0; i < 16<<20; i++) {
    // Generate a one-byte rune that isn't a control character (e.g. '\n').
    // Clipping to 0x20 introduces some bias, but we don't need uniformity.
    int b = rand() & 0x7F;
    if (b < 0x20)
      b = 0x20;
    text[i] = cast(char) b;
  }
  return text;
}

enum patterns = [
    // These three are easy because they have prefixes,
    // giving the search loop something to prefix accel.
    "EASY":      "ABCDEFGHIJKLMNOPQRSTUVWXYZ$",
    // This is a little harder, since it starts with a character class
    // and thus can't be memchr'ed.  Could look for ABC and work backward,
    // but no one does that.
    "MEDIUM":     "[XYZ]ABCDEFGHIJKLMNOPQRSTUVWXYZ$",
    // This is a fair amount harder, because of the leading [ -~]*.
    // A bad backtracking implementation will take O(text^2) time to
    // figure out there's no match.
    "HARD":       "[ -~]*ABCDEFGHIJKLMNOPQRSTUVWXYZ$"];


void main() {
  writeln("date: ", __DATE__);
  writeln("compiler: ", __VENDOR__, __VERSION__);

  static foreach (mode, regexp; patterns) {{
    writeln("=== ", mode, " ===");
    RE2 re = regexp;
    auto rtr = regex(regexp);
    auto ctr = ctRegex!regexp;

    writeln("bytes\tRE2\tstd.ctRegex\tstd.regex");
    foreach (b; 1 .. 8) {
      if (mode == "HARD" && b > 4) break;
      const n = 8 << (b * 3);
      auto text = RandomText(b);
      auto sp = StringPiece(text.ptr, n);
      auto r = benchmark!(
          {
            RE2.PartialMatch(sp, re);
          },
          {
            matchFirst(sp.toString, ctr);
          },
          {
            matchFirst(sp.toString, rtr);
          })(100);
      writeln(n, "\t",
              r[0].total!"nsecs", "\t",
              r[1].total!"nsecs", "\t",
              r[2].total!"nsecs");
    }
  }}
}
