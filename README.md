# re2d

D lanuage binding of https://github.com/google/re2

LICENSE: same as re2

## Usage

```d
import re2;

@nogc nothrow pure unittest {
  int i;
  StringPiece s;
  assert(RE2.FullMatch("ルビー:1234", "([^:]+):(\\d+)", &s, &i));
  assert(s.toString == "ルビー");
  assert(i == 1234);
}
```
