/*
TEST_OUTPUT:
---
fail_compilation/diag8044.d(109): Error: template instance `diag8044.test!(Enum.Bar)` does not match template declaration `test(Enum en)()`
  with `en = Bar`
  must satisfy the following constraint:
`       0`
fail_compilation/diag8044.d(109):        instantiated from here: `test!(Enum.Bar)`
fail_compilation/diag8044.d(102):        Candidate match: test(Enum en)() if (0)
---
 */

#line 100

enum Enum { Foo, Bar }
void test(Enum en)()
    if(0)
{
}

void main()
{
    test!(Enum.Bar)();
}
