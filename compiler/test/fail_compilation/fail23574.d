// https://issues.dlang.org/show_bug.cgi?id=23574
/*
TEST_OUTPUT:
---
fail_compilation/fail23574.d(32): Error: function `object._xopEquals` has no `return` statement, but is expected to return a value of type `bool`
bool _xopEquals()
     ^
Error: undefined identifier `size_t` in module `object`
fail_compilation/fail23574.d(40): Error: template instance `object.S17915!(MyClass)` error instantiating
        S17915!MyClass m_member;
        ^
fail_compilation/fail23574.d(36): Error: function `object.SDL_GetKeyName` has no `return` statement, but is expected to return a value of type `const(char)`
const(char)SDL_GetKeyName()
           ^
---
*/
module object;

class Object
{
}

bool opEquals(LHS, RHS)(LHS lhs, RHS)
{
    opEquals(cast()lhs);
}

class TypeInfo
{
}

bool _xopEquals()
{
}

const(char)SDL_GetKeyName()
{
    class MyClass
    {
        S17915!MyClass m_member;
    }
}

struct S17915(T)
{
    T owner;
}
