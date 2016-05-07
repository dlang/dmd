/*
TEST_OUTPUT:
---
fail_compilation/fail14251.d(19): Error: can only synchronize on a mutable object, not on 'this' of type 'const(B)'
fail_compilation/fail14251.d(33): Error: can only synchronize on a mutable object, not on 'con' of type 'const(A)'
fail_compilation/fail14251.d(36): Error: can only synchronize on a mutable object, not on 'imm' of type 'immutable(A)'
---
*/

class B
{
    void bar()
    {
        synchronized (this) {} // OK
    }

    void bar() const
    {
        synchronized (this) {} // Error
    }
}

class A
{
}

void main()
{
    A mut = new A;
    synchronized (mut) {} // OK

    const A con = new A;
    synchronized (con) {} // Error

    immutable A imm = new A;
    synchronized (imm) {} // Error
}
