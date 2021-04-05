// https://issues.dlang.org/show_bug.cgi?id=1654

/*
  TEST_OUTPUT:
  ---
  fail_compilation/traits_hasAliasing.d(10): Error: type expected as non-first argument of __traits `hasAliasing` instead of `""`
  ---
*/

enum _ = __traits(hasAliasing, "");
