/*
TEST_OUTPUT:
---
fail_compilation/bug19569.d(94): Error: `bug19569.test0` called with argument types `()` matches both:
fail_compilation/bug19569.d(80):     `bug19569.test0()`
and:
fail_compilation/bug19569.d(81):     `bug19569.test0()`
    test0();
         ^
fail_compilation/bug19569.d(95): Error: `bug19569.test1` called with argument types `()` matches both:
fail_compilation/bug19569.d(83):     `bug19569.test1()`
and:
fail_compilation/bug19569.d(84):     `bug19569.test1()`
    test1();
         ^
fail_compilation/bug19569.d(96): Error: `bug19569.test2` called with argument types `()` matches both:
fail_compilation/bug19569.d(86):     `bug19569.test2!().test2()`
and:
fail_compilation/bug19569.d(87):     `bug19569.test2!().test2()`
    test2();
         ^
fail_compilation/bug19569.d(97): Error: `bug19569.test3` called with argument types `()` matches both:
fail_compilation/bug19569.d(89):     `bug19569.test3!().test3()`
and:
fail_compilation/bug19569.d(90):     `bug19569.test3!().test3()`
    test3();
         ^
fail_compilation/bug19569.d(102): Error: `bug19569.test0` called with argument types `()` matches both:
fail_compilation/bug19569.d(80):     `bug19569.test0()`
and:
fail_compilation/bug19569.d(81):     `bug19569.test0()`
    test0();
         ^
fail_compilation/bug19569.d(103): Error: `bug19569.test1` called with argument types `()` matches both:
fail_compilation/bug19569.d(83):     `bug19569.test1()`
and:
fail_compilation/bug19569.d(84):     `bug19569.test1()`
    test1();
         ^
fail_compilation/bug19569.d(104): Error: `bug19569.test2` called with argument types `()` matches both:
fail_compilation/bug19569.d(86):     `bug19569.test2!().test2()`
and:
fail_compilation/bug19569.d(87):     `bug19569.test2!().test2()`
    test2();
         ^
fail_compilation/bug19569.d(105): Error: `bug19569.test3` called with argument types `()` matches both:
fail_compilation/bug19569.d(89):     `bug19569.test3!().test3()`
and:
fail_compilation/bug19569.d(90):     `bug19569.test3!().test3()`
    test3();
         ^
fail_compilation/bug19569.d(110): Error: `bug19569.test0` called with argument types `()` matches both:
fail_compilation/bug19569.d(80):     `bug19569.test0()`
and:
fail_compilation/bug19569.d(81):     `bug19569.test0()`
    test0();
         ^
fail_compilation/bug19569.d(111): Error: `bug19569.test1` called with argument types `()` matches both:
fail_compilation/bug19569.d(83):     `bug19569.test1()`
and:
fail_compilation/bug19569.d(84):     `bug19569.test1()`
    test1();
         ^
fail_compilation/bug19569.d(112): Error: `bug19569.test2` called with argument types `()` matches both:
fail_compilation/bug19569.d(86):     `bug19569.test2!().test2()`
and:
fail_compilation/bug19569.d(87):     `bug19569.test2!().test2()`
    test2();
         ^
fail_compilation/bug19569.d(113): Error: `bug19569.test3` called with argument types `()` matches both:
fail_compilation/bug19569.d(89):     `bug19569.test3!().test3()`
and:
fail_compilation/bug19569.d(90):     `bug19569.test3!().test3()`
    test3();
         ^
---
*/


void test0();
void test0() nothrow;

void test1();
void test1() @nogc;

void test2()();
void test2()() nothrow;

void test3()();
void test3()() @nogc;

void attr0()
{
    test0();
    test1();
    test2();
    test3();
}

void attr1() @nogc
{
    test0();
    test1();
    test2();
    test3();
}

void attr3() nothrow @nogc
{
    test0();
    test1();
    test2();
    test3();
}
