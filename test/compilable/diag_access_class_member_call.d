// REQUIRED_ARGS: -vcolumns -wi -unittest -diagnose=access -debug -dip25 -dip1000 -dip1008

/*
TEST_OUTPUT:
---
compilable/diag_access_class_member_call.d(70,7): Warning: unmodified public variable `c` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_class_member_call.d(76,7): Warning: unmodified public variable `c` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_class_member_call.d(82,7): Warning: unmodified public variable `c` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_class_member_call.d(105,7): Warning: unmodified public variable `c` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
---
*/

@safe pure:

extern(C++) struct Array(T)
{
    size_t length;
public:
    @disable this(this);
    ~this() pure nothrow {}     // no warn about const
}

alias Aint = Array!int;

struct S
{
pure:
    int z;
    void setZ(int z) { this.z = z; }
}

class D
{
    S s;
    int w;                      // no warn
}

class C
{
    int x;                      // no warn
    int y;                      // no warn
    S s;
    D d;
scope pure:
    void reset()
    {
        x = x.init;
        y = y.init;
    }
    int getX() const { return x; }
    int getY() const { return y; }
    void setX(int x) { this.x = x; }
    void setY(int y) { this.y = y; }
    void setXY(int x, int y) { setX(x); setY(y); }
    void setS(int z) { this.s.z = z; }
    void setSZ(int z) { this.s.setZ(z); }
    void setDw(int w) { this.d.w = w; }
    void setDSz(int z) { this.d.s.z = z; }
}

int f1()
{
    C c = new C();              // no warn
    c.reset();                  // because modified here
    return c.x + c.y;           // read here via fields
}

int f2()
{
    C c = new C();              // warn, unmodified should be `const`
    return c.x + c.y;           // read here via fields
}

int f3()
{
    C c = new C();              // warn, unmodified should be `const`
    return c.getX() + c.getY(); // read here via const member
}

int f4()
{
    C c = new C();              // warn, unmodified should be `const`
    const bool b;
    if (b)
        return c.x + c.y;       // ok, read here via fields
    else
        return c.getX() + c.getY(); // ok, read here via const member
}

void f5()
{
    void f(C c) {}
    C c = new C();              // no warn because is modified here below
    f(c);
}

void f6()
{
    C c = new C();              // no warn because modified
    c.setX(2);                  // here
}

int f7()
{
    C c = new C();              // warn, unmodified
    return c.getX();
}
