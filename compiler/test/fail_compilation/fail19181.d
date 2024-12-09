/*
TEST_OUTPUT:
---
fail_compilation/fail19181.d(17): Error: undefined identifier `LanguageError`
    s.foo(LanguageError);
          ^
---
*/
struct S
{
    void opDispatch(string name, T)(T arg) { }
}

void main()
{
    S s;
    s.foo(LanguageError);
}
