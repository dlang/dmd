/*
TEST_OUTPUT:
---
fail_compilation/fail7352.d(58): Error: template instance `Type!(1)` does not match template declaration `Type(T)`
    Type!a         testTypeValue;
    ^
fail_compilation/fail7352.d(59): Error: template instance `Type!(b)` does not match template declaration `Type(T)`
    Type!b         testTypeVar;
    ^
fail_compilation/fail7352.d(59):        `b` is not a type
fail_compilation/fail7352.d(60): Error: template instance `Type!(function () pure nothrow @nogc @safe => 1)` does not match template declaration `Type(T)`
    Type!(() => 1) testTypeFuncLiteral;
    ^
fail_compilation/fail7352.d(61): Error: template instance `Type!(fun)` does not match template declaration `Type(T)`
    Type!fun       testTypeFunc;
    ^
fail_compilation/fail7352.d(61):        `fun` is not a type
fail_compilation/fail7352.d(63): Error: template instance `Immutable!int` does not match template declaration `Immutable(T : immutable(T))`
    Immutable!int  testImmutable;
    ^
fail_compilation/fail7352.d(65): Error: template instance `Value!int` does not match template declaration `Value(string s)`
    auto testValueType      = Value!int.x;
                              ^
fail_compilation/fail7352.d(66): Error: template instance `Value!(1)` does not match template declaration `Value(string s)`
    auto testValueWrongType = Value!a.x;
                              ^
fail_compilation/fail7352.d(67): Error: template instance `Value!(fun)` does not match template declaration `Value(string s)`
    auto testValueFunc      = Value!fun.x;
                              ^
fail_compilation/fail7352.d(67):        `fun` is not of a value of type `string`
---
*/

template Type(T)
{
}

template Immutable(T : immutable(T))
{
    alias Immutable = T;
}

template Value(string s)
{
    auto x = s;
}

int fun(int i)
{
    return i;
}

void main()
{
    enum a = 1;
    int b;

    Type!a         testTypeValue;
    Type!b         testTypeVar;
    Type!(() => 1) testTypeFuncLiteral;
    Type!fun       testTypeFunc;

    Immutable!int  testImmutable;

    auto testValueType      = Value!int.x;
    auto testValueWrongType = Value!a.x;
    auto testValueFunc      = Value!fun.x;
}
