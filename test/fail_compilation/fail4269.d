// REQUIRED_ARGS: -d

/***************************************/
/*
TEST_OUTPUT:
---
fail_compilation/fail4269.d(17): Error: undefined identifier B1, did you mean interface A1?
fail_compilation/fail4269.d(17): Error: variable fail4269.A1.blah field not allowed in interface
fail_compilation/fail4269.d(18): Error: undefined identifier B1, did you mean interface A1?
fail_compilation/fail4269.d(18): Error: function fail4269.A1.foo function body only allowed in final functions in interface A1
---
*/

enum bool WWW1 = is(typeof(A1.x));
interface A1
{
    B1 blah;
    void foo(B1 b) {}
}

/***************************************/
/*
TEST_OUTPUT:
---
fail_compilation/fail4269.d(33): Error: undefined identifier B2, did you mean struct A2?
fail_compilation/fail4269.d(34): Error: undefined identifier B2, did you mean struct A2?
---
*/

enum bool WWW2 = is(typeof(A2.x));
struct A2
{
    B2 blah;
    void foo(B2 b) {}
}

/***************************************/
/*
TEST_OUTPUT:
---
fail_compilation/fail4269.d(49): Error: undefined identifier B3, did you mean class A3?
fail_compilation/fail4269.d(50): Error: undefined identifier B3, did you mean class A3?
---
*/

enum bool WWW3 = is(typeof(A3.x));
class A3
{
    B3 blah;
    void foo(B3 b) {}
}

/***************************************/
/*
TEST_OUTPUT:
---
fail_compilation/fail4269.d(62): Error: undefined identifier Y4, did you mean alias X4?
---
*/

static if (is(typeof(X4.init))) {}
alias Y4 X4;

/***************************************/
/*
TEST_OUTPUT:
---
fail_compilation/fail4269.d(73): Error: undefined identifier Y5, did you mean typedef X5?
---
*/

static if (is(typeof(X5.init))) {}
typedef Y5 X5;

/***************************************/
/*
TEST_OUTPUT:
---
fail_compilation/fail4269.d(84): Error: alias fail4269.X6 cannot resolve
---
*/

static if (is(typeof(X6))) {}
alias X6 X6;

/***************************************/
/*
TEST_OUTPUT:
---
fail_compilation/fail4269.d(96): Error: alias fail4269.X7 cannot alias an expression d7[1]
---
*/

int[2] d7;
static if (is(typeof(X7.init))) {}
alias d7[1] X7;

/***************************************/
// 9879
/*
TEST_OUTPUT:
---
fail_compilation/fail4269.d(112): Error: undefined identifier SX8, did you mean struct S8?
fail_compilation/fail4269.d(113): Error: undefined identifier CX8, did you mean class C8?
fail_compilation/fail4269.d(117): Error: undefined identifier SX9, did you mean struct S9?
fail_compilation/fail4269.d(118): Error: undefined identifier CX9, did you mean class C9?
---
*/

static if (__traits(compiles, S8.sizeof)) pragma(msg, "S8.sizeof compiles!");
static if (__traits(compiles, C8.sizeof)) pragma(msg, "C8.sizeof compiles!");
struct S8 { void foo(SX8 b); }
class  C8 { void foo(CX8 b); }

static if (is(typeof(S9.sizeof))) pragma(msg, "S9.sizeof compiles!");
static if (is(typeof(C9.sizeof))) pragma(msg, "C9.sizeof compiles!");
struct S9 { void foo(SX9 b); }
class  C9 { void foo(CX9 b); }

/***************************************/
