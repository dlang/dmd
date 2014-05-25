// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

/***************** AssignExp *******************/

/*
TEST_OUTPUT:
---
fail_compilation/nogc3.d(16): Error: setting 'length' in @nogc function testArrayLength may cause GC allocation
fail_compilation/nogc3.d(17): Error: setting 'length' in @nogc function testArrayLength may cause GC allocation
fail_compilation/nogc3.d(18): Error: setting 'length' in @nogc function testArrayLength may cause GC allocation
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

/*
TEST_OUTPUT:
---
fail_compilation/nogc3.d(35): Error: @nogc function 'nogc3.testCall' cannot call non-@nogc function pointer 'fp'
fail_compilation/nogc3.d(36): Error: @nogc function 'nogc3.testCall' cannot call non-@nogc function 'nogc3.barCall'
---
*/
@nogc void testCall()
{
    auto fp = &barCall;
    (*fp)();
    barCall();
}

/****************** Closure ***********************/

@nogc void takeDelegate2(scope int delegate() dg) {}
@nogc void takeDelegate3(      int delegate() dg) {}

/*
TEST_OUTPUT:
---
fail_compilation/nogc3.d(51): Error: function nogc3.testClosure1 @nogc function allocates a closure with the GC
fail_compilation/nogc3.d(63): Error: function nogc3.testClosure3 @nogc function allocates a closure with the GC
---
*/
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
