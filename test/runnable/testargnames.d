/*
PERMUTE_ARGS:
*/

import core.stdc.stdio;

void check(string name, string expected, string file = __FILE__, int line = __LINE__)
{
  if(name == expected) return;
  import std.conv;
  assert(0, text("name:{", name, "} expected:{", expected, "} at ", file, ":", line));
}

// Simple yet useful log function
string log(T)(T a, string name=__ARG_STRING__!a)
{
  import std.conv;
  return text(name, ":", a);
}

void fun1(int a, string expected, string name=__ARG_STRING__!a)
{
  check(name, expected);
}

void fun2(int a, string b, double c, string expected, string name=__ARG_STRING__!b)
{
  check(name, expected);
}

void fun_UFCS(int a, string expected, string name=__ARG_STRING__!a)
{
  check(name, expected);
}

void fun_template(T)(T a, string expected, string name=__ARG_STRING__!a)
{
  check(name, expected);
}

void main()
{
  int a=42;

  check(log(1+a), `1 + a:43`);

  fun1(41+a, `41 + a`);

  string bar="bob";
  fun2(41+a, "foo"~bar, 0.0, `"foo" ~ bar`);

  (1+1).fun_UFCS("1 + 1");

  fun_template(1+3, `1 + 3`);

  fun1(a+a+a, `a + a + a`);

  // Checks that no constant folding happens, cf D20180130T161632.
  fun1(1+1+2, `1 + 1 + 2`);

  static const int x=44;
  fun1(x+x+x, `x + x + x`);

  // TODO: we'd like to have `t + t` instead; the conversion happens in arrayExpressionSemantic before we can tell whether candidate matching function has argument stringification (cf callMatch)
  enum t=44;
  fun1(t+t, `44 + 44`);
}
