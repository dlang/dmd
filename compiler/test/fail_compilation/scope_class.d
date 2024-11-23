/*
TEST_OUTPUT:
---
fail_compilation/scope_class.d(14): Error: functions cannot return `scope scope_class.C`
C increment(C c)
  ^
---
*/



scope class C { int i; }    // Notice the use of `scope` here

C increment(C c)
{
    c.i++;
    return c;
}

void main()
{
    scope C c = new C();
    c.increment();
}
