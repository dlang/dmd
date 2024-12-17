/*
REQUIRED_ARGS: -vcolumns
TEST_OUTPUT:
---
fail_compilation/templatesingleparam.d(17,14): Error: identifier character cannot follow string `c` postfix without whitespace
fail_compilation/templatesingleparam.d(18,10): Error: identifier character cannot follow integer `U` suffix without whitespace
fail_compilation/templatesingleparam.d(22,6): Error: identifier character cannot follow string `d` postfix without whitespace
fail_compilation/templatesingleparam.d(23,4): Error: identifier character cannot follow float `f` suffix without whitespace
---
*/
class Foo(alias str) {
  enum STR = str;
}

class Bar {
  Foo!q{foo}bb; // OK
  Foo!q{foo}cc;
  Foo!2LUNGS;
}

@`_`int i; // OK
@`_`dint di;
@2flong fi;
@0xFeedObject obj; // not caught
