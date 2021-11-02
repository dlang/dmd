// REQUIRED_ARGS: -vcolumns -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_return_member.d(20,5): Warning: member constructor `this` should be qualified as `const`, because it doesn't modify `this`
compilable/diag_access_return_member.d(40,12): Warning: returned expression is always `null`
compilable/diag_access_return_member.d(47,12): Warning: returned expression is always `null`
compilable/diag_access_return_member.d(54,12): Warning: returned expression is always `null`
---
*/

@safe pure:

class Child
{
    this() @safe pure           // warn, should be const
    {
    }
    this(int child) @safe pure     // TODO: no warn, member of `this` is modified
    {
        auto _ = this;
        this.child = child;
    }
    int child;
}
class Parent
{
    Child child;
}

Child f1()
{
    return new Child();
}

Child f2()
{
    Parent parent = new Parent();
    return parent.child; // warn, `parent.child` is `null` because `Parent` has no explicit constructor
}

Child f3()
{
    Parent parent = new Parent();
    parent.child = new Child();
    return parent.child;        // no warn
}

Child f4()
{
    Parent parent = new Parent();
    Child child = parent.child;  // `parent.child` is `null` because `Parent` has no explicit constructor
    return child;                // warn, null return
}
