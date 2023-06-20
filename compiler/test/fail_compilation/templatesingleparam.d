/*
REQUIRED_ARGS: -vcolumns
TEST_OUTPUT:
---
fail_compilation/templatesingleparam.d(17,14): Error: alphanumeric character cannot follow string literal `c` postfix without whitespace
fail_compilation/templatesingleparam.d(18,10): Error: alphanumeric character cannot follow numeric literal `2LU` without whitespace
fail_compilation/templatesingleparam.d(22,6): Error: alphanumeric character cannot follow string literal `d` postfix without whitespace
fail_compilation/templatesingleparam.d(23,8): Error: alphanumeric character cannot follow numeric literal `0xFeed` without whitespace
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
@0xFeedObject obj;
