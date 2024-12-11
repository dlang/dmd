// REQUIRED_ARGS: -o-

/***************** AssignExp *******************/

/*
TEST_OUTPUT:
---
fail_compilation/nogc3.d(57): Error: setting `length` in `@nogc` function `nogc3.testArrayLength` may cause a GC allocation
    a.length = 3;
             ^
fail_compilation/nogc3.d(58): Error: setting `length` in `@nogc` function `nogc3.testArrayLength` may cause a GC allocation
    a.length += 1;
             ^
fail_compilation/nogc3.d(59): Error: setting `length` in `@nogc` function `nogc3.testArrayLength` may cause a GC allocation
    a.length -= 1;
             ^
fail_compilation/nogc3.d(69): Error: `@nogc` function `nogc3.testCall` cannot call non-@nogc function pointer `fp`
    (*fp)();
         ^
fail_compilation/nogc3.d(70): Error: `@nogc` function `nogc3.testCall` cannot call non-@nogc function `nogc3.barCall`
    barCall();
           ^
fail_compilation/nogc3.d(78): Error: function `nogc3.testClosure1` is `@nogc` yet allocates closure for `testClosure1()` with the GC
@nogc auto testClosure1()
           ^
fail_compilation/nogc3.d(81):        function `nogc3.testClosure1.bar` closes over variable `x`
    int bar() { return x; }
        ^
fail_compilation/nogc3.d(80):        `x` declared here
    int x;
        ^
fail_compilation/nogc3.d(90): Error: function `nogc3.testClosure3` is `@nogc` yet allocates closure for `testClosure3()` with the GC
@nogc void testClosure3()
           ^
fail_compilation/nogc3.d(93):        function `nogc3.testClosure3.bar` closes over variable `x`
    int bar() { return x; }
        ^
fail_compilation/nogc3.d(92):        `x` declared here
    int x;
        ^
fail_compilation/nogc3.d(102): Error: array literal in `@nogc` function `nogc3.foo13702` may cause a GC allocation
        return [1];     // error
               ^
fail_compilation/nogc3.d(103): Error: array literal in `@nogc` function `nogc3.foo13702` may cause a GC allocation
    return 1 ~ [2];     // error
           ^
fail_compilation/nogc3.d(109): Error: array literal in `@nogc` function `nogc3.bar13702` may cause a GC allocation
    auto aux = 1 ~ [2]; // error
               ^
fail_compilation/nogc3.d(108): Error: array literal in `@nogc` function `nogc3.bar13702` may cause a GC allocation
        return [1];     // error <- no error report
               ^
---
*/
@nogc void testArrayLength(int[] a)
{
    a.length = 3;
    a.length += 1;
    a.length -= 1;
}

/***************** CallExp *******************/

void barCall();

@nogc void testCall()
{
    auto fp = &barCall;
    (*fp)();
    barCall();
}

/****************** Closure ***********************/

@nogc void takeDelegate2(scope int delegate() dg) {}
@nogc void takeDelegate3(      int delegate() dg) {}

@nogc auto testClosure1()
{
    int x;
    int bar() { return x; }
    return &bar;
}
@nogc void testClosure2()
{
    int x;
    int bar() { return x; }
    takeDelegate2(&bar);     // no error
}
@nogc void testClosure3()
{
    int x;
    int bar() { return x; }
    takeDelegate3(&bar);
}

/****************** ErrorExp ***********************/

int[] foo13702(bool b) @nogc
{
    if (b)
        return [1];     // error
    return 1 ~ [2];     // error
}
int[] bar13702(bool b) @nogc
{
    if (b)
        return [1];     // error <- no error report
    auto aux = 1 ~ [2]; // error
    return aux;
}
