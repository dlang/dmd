/*
Informative error messages if the compiler generated destructor overrides a user-defined one.

TEST_OUTPUT:
---
fail_compilation/dtor_attributes.d(142): Error: `pure` function `dtor_attributes.test1` cannot call impure destructor `dtor_attributes.Strict.~this`
    Strict s;
           ^
fail_compilation/dtor_attributes.d(137):        generated `Strict.~this` is impure because of the following field's destructors:
    ~this() pure nothrow @nogc @safe {}
    ^
fail_compilation/dtor_attributes.d(135):         - HasDtor member
    HasDtor member;
            ^
fail_compilation/dtor_attributes.d(127):           impure `HasDtor.~this` is declared here
    ~this() {}
    ^
fail_compilation/dtor_attributes.d(142): Error: `@safe` function `dtor_attributes.test1` cannot call `@system` destructor `dtor_attributes.Strict.~this`
    Strict s;
           ^
fail_compilation/dtor_attributes.d(137):        `dtor_attributes.Strict.~this` is declared here
    ~this() pure nothrow @nogc @safe {}
    ^
fail_compilation/dtor_attributes.d(137):        generated `Strict.~this` is @system because of the following field's destructors:
fail_compilation/dtor_attributes.d(135):         - HasDtor member
    HasDtor member;
            ^
fail_compilation/dtor_attributes.d(127):           @system `HasDtor.~this` is declared here
    ~this() {}
    ^
fail_compilation/dtor_attributes.d(142): Error: `@nogc` function `dtor_attributes.test1` cannot call non-@nogc destructor `dtor_attributes.Strict.~this`
    Strict s;
           ^
fail_compilation/dtor_attributes.d(137):        generated `Strict.~this` is non-@nogc because of the following field's destructors:
    ~this() pure nothrow @nogc @safe {}
    ^
fail_compilation/dtor_attributes.d(135):         - HasDtor member
    HasDtor member;
            ^
fail_compilation/dtor_attributes.d(127):           non-@nogc `HasDtor.~this` is declared here
    ~this() {}
    ^
fail_compilation/dtor_attributes.d(142): Error: destructor `dtor_attributes.Strict.~this` is not `nothrow`
    Strict s;
           ^
fail_compilation/dtor_attributes.d(137):        generated `Strict.~this` is not nothrow because of the following field's destructors:
    ~this() pure nothrow @nogc @safe {}
    ^
fail_compilation/dtor_attributes.d(135):         - HasDtor member
    HasDtor member;
            ^
fail_compilation/dtor_attributes.d(127):           not nothrow `HasDtor.~this` is declared here
    ~this() {}
    ^
fail_compilation/dtor_attributes.d(140): Error: function `dtor_attributes.test1` may throw but is marked as `nothrow`
void test1() pure nothrow @nogc @safe
     ^
fail_compilation/dtor_attributes.d(155): Error: `pure` function `dtor_attributes.test2` cannot call impure destructor `dtor_attributes.StrictClass.~this`
    scope instance = new StrictClass();
          ^
fail_compilation/dtor_attributes.d(150):        generated `StrictClass.~this` is impure because of the following field's destructors:
    ~this() pure {}
    ^
fail_compilation/dtor_attributes.d(149):         - HasDtor member
    HasDtor member;
            ^
fail_compilation/dtor_attributes.d(127):           impure `HasDtor.~this` is declared here
    ~this() {}
    ^
fail_compilation/dtor_attributes.d(180): Error: `pure` function `dtor_attributes.test3` cannot call impure destructor `dtor_attributes.StrictStructRef.~this`
    StrictStructRef structInstance;
                    ^
fail_compilation/dtor_attributes.d(175):        generated `StrictStructRef.~this` is impure because of the following field's destructors:
    ~this() pure {}
    ^
fail_compilation/dtor_attributes.d(169):         - HasDtor structMember
    HasDtor structMember;
            ^
fail_compilation/dtor_attributes.d(127):           impure `HasDtor.~this` is declared here
    ~this() {}
    ^
fail_compilation/dtor_attributes.d(195): Error: `pure` function `dtor_attributes.test4` cannot call impure destructor `dtor_attributes.StrictNested.~this`
    StrictNested structInstance;
                 ^
fail_compilation/dtor_attributes.d(190):        generated `StrictNested.~this` is impure because of the following field's destructors:
    ~this() pure {}
    ^
fail_compilation/dtor_attributes.d(187):         - HasDtor[4] arrayMember
    HasDtor[4] arrayMember;
               ^
fail_compilation/dtor_attributes.d(127):           impure `HasDtor.~this` is declared here
    ~this() {}
    ^
fail_compilation/dtor_attributes.d(208): Error: `pure` function `dtor_attributes.test5` cannot call impure destructor `dtor_attributes.Permissive.~this`
    Permissive structInstance;
               ^
fail_compilation/dtor_attributes.d(230): Error: `pure` function `dtor_attributes.test6` cannot call impure destructor `dtor_attributes.HasNestedDtor3.~this`
    HasNestedDtor3 instance;
                   ^
fail_compilation/dtor_attributes.d(223):        generated `HasNestedDtor3.~this` is impure because of the following field's destructors:
struct HasNestedDtor3
^
fail_compilation/dtor_attributes.d(225):         - HasNestedDtor2 member3
    HasNestedDtor2 member3;
                   ^
fail_compilation/dtor_attributes.d(218):        generated `HasNestedDtor2.~this` is impure because of the following field's destructors:
struct HasNestedDtor2
^
fail_compilation/dtor_attributes.d(220):         - HasNestedDtor1 member2
    HasNestedDtor1 member2;
                   ^
fail_compilation/dtor_attributes.d(213):        generated `HasNestedDtor1.~this` is impure because of the following field's destructors:
struct HasNestedDtor1
^
fail_compilation/dtor_attributes.d(215):         - HasDtor member1
    HasDtor member1;
            ^
fail_compilation/dtor_attributes.d(127):           impure `HasDtor.~this` is declared here
    ~this() {}
    ^
---
*/
// Line 100 starts here

struct HasDtor
{
    ~this() {}
}

// The user-defined dtor is overridden by a generated dtor calling both
// - HasDtor.~this
// - Strict.~this
struct Strict
{
    HasDtor member;

    ~this() pure nothrow @nogc @safe {}
}

void test1() pure nothrow @nogc @safe
{
    Strict s;
}

// Line 200 starts here

class StrictClass
{
    HasDtor member;
    ~this() pure {}
}

void test2() pure
{
    scope instance = new StrictClass();
}

// Line 300 starts here

class HasDtorClass
{
    ~this() {}
}

struct Empty {}

struct StrictStructRef
{
    HasDtor structMember;
    HasDtorClass classMember;
    int intMember;
    int[2] arrayMember;
    Empty e;

    ~this() pure {}
}

void test3() pure
{
    StrictStructRef structInstance;
}

// Line 400 starts here

struct StrictNested
{
    HasDtor[4] arrayMember;
    HasDtorClass[4] classMember;

    ~this() pure {}
}

void test4() pure
{
    StrictNested structInstance;
}

// Line 500 starts here

struct Permissive
{
    HasDtor[4] arrayMember;
    ~this() {}
}

void test5() pure
{
    Permissive structInstance;
}

// Line 600 starts here

struct HasNestedDtor1
{
    HasDtor member1;
}

struct HasNestedDtor2
{
    HasNestedDtor1 member2;
}

struct HasNestedDtor3
{
    HasNestedDtor2 member3;
}

void test6() pure
{
    HasNestedDtor3 instance;
}
