# re2d

[![linux](https://github.com/ShigekiKarita/re2d/actions/workflows/linux.yml/badge.svg)](https://github.com/ShigekiKarita/re2d/actions/workflows/linux.yml)
[![codecov](https://codecov.io/gh/ShigekiKarita/re2d/branch/master/graph/badge.svg?token=3SFV852DK7)](https://codecov.io/gh/ShigekiKarita/re2d)
[![Dub version](https://img.shields.io/dub/v/re2d.svg)](https://code.dlang.org/packages/re2d)


D language binding of [RE2](https://github.com/google/re2) regex engine.

LICENSE: same as RE2 (BSD 3-clause).

## Usage

```d
/* dub.json:
{
  "dependencies": {
     "re2d": "*"
  },
  "libs": ["re2", "c++"]
}
*/
import re2d;

@nogc nothrow pure unittest {
  int i;
  StringPiece s;
  assert(RE2.FullMatch("ルビー💎:1234", `([^:]+):(\d+)`, &s, &i));
  assert(s.toString == "ルビー💎");
  assert(i == 1234);
}
```

You need to install RE2 library in `$LIBRARY_PATH` and `$LD_LIBRARY_PATH` before building.
