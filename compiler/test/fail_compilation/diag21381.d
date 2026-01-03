/*
TEST_OUTPUT:
---
fail_compilation/diag21381.d(15): Error: undefined identifier `xyx`, did you mean struct `xyz`?
---
*/
// https://github.com/dlang/dmd/issues/21381

enum plusOne(int x) = x + 1;
struct xyz{}

alias PlusOne =
  plusOne
  !
  xyx;
  