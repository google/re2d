module re2d;

public import re2d.stringpiece;
public import re2d.re2;

@nogc nothrow pure unittest {
  int i;
  StringPiece s;
  assert(RE2.FullMatch("ルビー:1234", "([^:]+):(\\d+)", &s, &i));
  assert(s.toString == "ルビー");
  assert(i == 1234);
}
