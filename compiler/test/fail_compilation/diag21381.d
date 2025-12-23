// https://github.com/dlang/dmd/issues/21381

/*
TEST_OUTPUT:
---
fail_compilation/diag21381.d(16): Error: undefined identifier `xyx`, did you mean struct `xyz`?
---
*/

enum plusOne(int x) = x + 1;
struct xyz{}

alias PlusOne =
  plusOne
  !
  xyx;
  