// REQUIRED_ARGS: -vcolumns -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_this.d(33,9): Warning: member function `getX` should be qualified as `const`, because it doesn't modify `this`
---
*/

@safe pure:

class C
{
@safe pure:
    this(int x)
    {
        this.x = x;
    }
    ~this() {}                  // no warn about const
    inout(C) getThis() inout
    {
        return getThis();
        // return this;            // no warn, because `inout`
    }
    void setX(int x)
    {
        this.x = x;          // no warn, because mutates `this`
    }
    int getX() const
    {
        return this.x;          // no warn, because `const`
    }
    int getX()                // warn, member `getX` should be qualified `const`
    {
        return this.x;
    }
    int getX_()               // TODO: warn, member `getX` should be qualified `const`
    {
        return 32;
    }
    void setX_(int)          // TODO: warn, member `setX_` should be qualified `const`
    {
    }
    int getXconst() const       // no warn, because `const`
    {
        return this.x;
    }
    int getXimmutable() immutable // no warn, because `immutable`
    {
        return this.x;
    }
    inout(int) getXimmutable() inout // no warn, because `inout`
    {
        return this.x;
    }
    static C foo(C c) { return c; }
    void goo() { foo(this); }   // no warn
    int x;
}
