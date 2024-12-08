/*
TEST_OUTPUT:
---
fail_compilation/fail44.d(20): Error: expression `bar[i]` is `void` and has no value
    foo[i] = bar[i];
                ^
---
*/

void Foo()
{
  void[] bar;
  void[] foo;

  bar.length = 50;
  foo.length = 50;

  for(size_t i=0; i<50; i++)
  {
    foo[i] = bar[i];
  }
}
