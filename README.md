# re2d

D language binding of [RE2](https://github.com/google/re2) regex engine.

LICENSE: same as RE2 (BSD 3-clause).

## Usage

```d
import re2d;

@nogc nothrow pure unittest {
  int i;
  StringPiece s;
  assert(RE2.FullMatch("ルビー:1234", "([^:]+):(\\d+)", &s, &i));
  assert(s.toString == "ルビー");
  assert(i == 1234);
}
```
