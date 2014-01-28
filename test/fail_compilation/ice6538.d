

/**************************************/
// 6538

template allSatisfy(alias F, T...) { enum bool allSatisfy = true; }
template isIntegral(T) { enum bool isIntegral = true; }

/*
TEST_OUTPUT:
---
fail_compilation/ice6538.d(17): Error: cannot take a not yet instantiated symbol 'sizes' inside template constraint
fail_compilation/ice6538.d(22): Error: template ice6538.foo cannot deduce function from argument types !()(int, int), candidates are:
fail_compilation/ice6538.d(17):        ice6538.foo(I...)(I sizes) if (allSatisfy!(isIntegral, sizes))
---
*/
void foo(I...)(I sizes)
if (allSatisfy!(isIntegral, sizes)) {}

void test6538a()
{
    foo(42, 86);
}

/*
TEST_OUTPUT:
---
fail_compilation/ice6538.d(34): Error: cannot take a not yet instantiated symbol 't1' inside template constraint
fail_compilation/ice6538.d(34): Error: cannot take a not yet instantiated symbol 't2' inside template constraint
fail_compilation/ice6538.d(39): Error: template ice6538.bar cannot deduce function from argument types !()(int, int), candidates are:
fail_compilation/ice6538.d(34):        ice6538.bar(T1, T2)(T1 t1, T2 t2) if (allSatisfy!(isIntegral, t1, t2))
---
*/
void bar(T1, T2)(T1 t1, T2 t2)
if (allSatisfy!(isIntegral, t1, t2)) {}

void test6538b()
{
    bar(42, 86);
}

/**************************************/
// 9361

template Sym(alias A)
{
    enum Sym = true;
}

/*
TEST_OUTPUT:
---
fail_compilation/ice6538.d(60): Error: cannot take a not yet instantiated symbol 'this' inside template constraint
fail_compilation/ice6538.d(66): Error: template ice6538.S.foo cannot deduce function from argument types !()(), candidates are:
fail_compilation/ice6538.d(60):        ice6538.S.foo()() if (Sym!this)
---
*/
struct S
{
    void foo()() if (Sym!(this)) {}
    void bar()() { static assert(Sym!(this)); }   // OK
}
void test9361a()
{
    S s;
    s.foo();    // fail
    s.bar();    // OK
}

/*
TEST_OUTPUT:
---
fail_compilation/ice6538.d(81): Error: cannot take a not yet instantiated symbol 'super' inside template constraint
fail_compilation/ice6538.d(86): Error: template ice6538.D.foo cannot deduce function from argument types !()(), candidates are:
fail_compilation/ice6538.d(81):        ice6538.D.foo()() if (Sym!(super))
---
*/
class C {}
class D : C
{
    void foo()() if (Sym!(super)) {}
}
void test9361b()
{
    auto d = new D();
    d.foo();
}

