module re2;

public import re2.stringpiece;
public import re2.re2;

@nogc nothrow pure unittest {
  int i;
  StringPiece s;
  assert(RE2.FullMatch("ルビー:1234", "([^:]+):(\\d+)", &s, &i));
  assert(s.toString == "ルビー");
  assert(i == 1234);
}
