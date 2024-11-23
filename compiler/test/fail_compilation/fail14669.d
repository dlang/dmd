/*
TEST_OUTPUT:
---
fail_compilation/fail14669.d(33): Error: `auto` can only be used as part of `auto ref` for template function parameters
void foo1()(auto int a) {}
     ^
fail_compilation/fail14669.d(38): Error: template instance `fail14669.foo1!()` error instantiating
    alias f1 = foo1!();
               ^
fail_compilation/fail14669.d(34): Error: `auto` can only be used as part of `auto ref` for template function parameters
void foo2()(auto int a) {}
     ^
fail_compilation/fail14669.d(39): Error: template `foo2` is not callable using argument types `!()(int)`
    foo2(1);
        ^
fail_compilation/fail14669.d(34):        Candidate is: `foo2()(auto int a)`
void foo2()(auto int a) {}
     ^
fail_compilation/fail14669.d(42): Error: cannot explicitly instantiate template function with `auto ref` parameter
void bar1(T)(auto ref T x) {}
     ^
fail_compilation/fail14669.d(51): Error: template instance `fail14669.bar1!int` error instantiating
    alias b1 = bar1!(int);
               ^
fail_compilation/fail14669.d(43): Error: cannot explicitly instantiate template function with `auto ref` parameter
void bar2(T)(auto ref T x) {}
     ^
fail_compilation/fail14669.d(53): Error: template instance `fail14669.bar2!int` error instantiating
    alias b2 = bar2!(int);
               ^
---
*/
void foo1()(auto int a) {}
void foo2()(auto int a) {}

void test1()
{
    alias f1 = foo1!();
    foo2(1);
}

void bar1(T)(auto ref T x) {}
void bar2(T)(auto ref T x) {}

void test2()
{
    int n;

    bar1(1);
    bar1(n);
    alias b1 = bar1!(int);

    alias b2 = bar2!(int);
    bar2(n);
    bar2(1);
}
