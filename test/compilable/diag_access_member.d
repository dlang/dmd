// REQUIRED_ARGS: -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_member.d(44): Warning: unmodified public variable `s` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
---
*/

struct S
{
    int x;
    void f()
    {
        x = 1;                  // warn
        x = 1;                  // warn
    }
    void g()
    {
        x = 1;
    }
}

class C
{
    this(int a, int b)          // warn
    {
        this.a = a;
        this.b = b;
    }
    public int a;
    private int b;
}

int f1()
{
    S s;                        // warn
    s.x = 11;
    return s.x;                 // no warn
}

bool f2()
{
    S s;                        // warn
    const x = s.x;
    return s.x == x;
}
