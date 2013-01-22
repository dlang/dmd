/*
TEST_OUTPUT:
---
fail_compilation/ice9361.d(18): Error: 'this' cannot pass to alias parameter inside template constraint
fail_compilation/ice9361.d(18): Error: template instance Sym!(this) Sym!(this) does not match template declaration Sym(alias A)
fail_compilation/ice9361.d(25): Error: template ice9361.S.foo does not match any function template declaration. Candidates are:
fail_compilation/ice9361.d(18):        ice9361.S.foo()() if (Sym!(this))
fail_compilation/ice9361.d(25): Error: template ice9361.S.foo()() if (Sym!(this)) cannot deduce template function from argument types !()()
---
*/

template Sym(alias A)
{
    enum Sym = true;
}
struct S
{
  void foo()() if (Sym!(this)) {}
  void bar()() { static assert(Sym!(this)); }   // OK
}

void test()
{
    S s;
    s.foo();    // fail
    s.bar();    // OK
}
