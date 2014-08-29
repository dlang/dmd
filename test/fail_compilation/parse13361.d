/*
TEST_OUTPUT:
---
fail_compilation/parse13361.d(10): Error: empty attribute list is not allowed
fail_compilation/parse13361.d(13): Error: empty attribute list is not allowed
---
*/
struct A
{
  @()
    int b;

  []    // deprecated style
    int c;
}
