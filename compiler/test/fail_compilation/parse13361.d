/*
TEST_OUTPUT:
---
fail_compilation/parse13361.d(17): Error: empty attribute list is not allowed
  @()
   ^
fail_compilation/parse13361.d(20): Error: empty attribute list is not allowed
  []    // deprecated style
  ^
fail_compilation/parse13361.d(20): Error: use `@(attributes)` instead of `[attributes]`
  []    // deprecated style
  ^
---
*/
struct A
{
  @()
    int b;

  []    // deprecated style
    int c;
}
