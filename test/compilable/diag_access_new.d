// REQUIRED_ARGS: -vcolumns -wi -unittest -diagnose=access -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_new.d(41,5): Warning: unused local parameter `this` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_new.d(41,5): Warning: member constructor `this` should be qualified as `const`, because it doesn't modify `this`
compilable/diag_access_new.d(52,12): Warning: dereferencing null `c`
compilable/diag_access_new.d(59,12): Warning: dereferencing null `s`
compilable/diag_access_new.d(68,12): Warning: dereferencing null `c`
compilable/diag_access_new.d(103,12): Warning: dereferencing maybe null `c`
compilable/diag_access_new.d(115,12): Warning: dereferencing maybe null `c`
compilable/diag_access_new.d(141,12): Warning: dereferencing null `c`
compilable/diag_access_new.d(150,16): Warning: dereferencing null `c`
compilable/diag_access_new.d(162,9): Warning: dereferencing maybe null `c`
compilable/diag_access_new.d(177,16): Warning: dereferencing null `c`
compilable/diag_access_new.d(196,12): Warning: dereferencing maybe null `c`
compilable/diag_access_new.d(196,18): Warning: dereferencing maybe null `d`
compilable/diag_access_new.d(209,12): Warning: dereferencing null `c`
compilable/diag_access_new.d(223,12): Warning: dereferencing null `c`
compilable/diag_access_new.d(229,16): Warning: dereferencing null `c`
compilable/diag_access_new.d(230,12): Warning: dereferencing null `c`
compilable/diag_access_new.d(244,12): Warning: dereferencing null `c`
compilable/diag_access_new.d(271,12): Warning: dereferencing null `d`
compilable/diag_access_new.d(277,12): Warning: variable `c` is unconditionally `true`, `assert` is not needed
compilable/diag_access_new.d(283,12): Warning: variable `c` is unconditionally `false`
---
*/

class C
{
    this(int x = 0)
    {
        this.x = x;
    }
    public int x;
}

struct S
{
    this(int x)                 // TODO: no warn
    {
        this.x = x;
    }
    public int x;
}

int f10a(const C c)
{
    if (c is null)
        return 0;
    return c.x;                 // TODO: no warn
}

int f10a_S(const S* s)
{
    if (s is null)
        return 0;
    return s.x;                 // TODO: no warn
}

int f10a_C(const C c)
{
    if (c is null)
    {
        return 0;
    }
    return c.x;                 // TODO: no warn
}

int f10b_C(const C c)
{
    if (c !is null)
        return c.x;
    return 0;
}

int f10b_S(const S* s)
{
    if (s !is null)
        return s.x;
    return 0;
}

bool f0()
{
    C c = new C(11);            // TODO: warn, should be `const` or `immutable`
    const x = c.x;
    return c.x == x;
}

bool f3b()
{
    C c = new C(11);            // TODO: warn, should be `const` or `immutable`
    const x = c.x;
    return c.x == x;
}

int f1a(const C c)
{
    if (const C d = c)
        return d.x;
    return c.x;                 // error
}

void f(int x) {}

int f1b(C c)
{
    if (const C d = c)
    {
        f(d.x);
        return d.x;             // no warn, because `d` is non-null here
    }
    return c.x;                 // error
}

int f8(const C c, const C d)
{
    if (c)
        if (d)
            return c.x + d.x;   // ok, by also checking enclosing scopes until `c`'s state is found
    return 0;
}

void resetViaRef(ref C c)
{
    c = C.init;
}

void resetViaPtr(C* c)
{
    *c = null; // TODO: infer that `c` is set to null in caller context of `resetViaPtr`
}

int f0a(C c)
{
    if (!c)
        return 0;
    resetViaRef(c);
    return c.x;                 // warn, maybe null
}

int f0b(C c)
{
    if (!c)
        return 0;
    const x = c.x;              // ok, `c` is not null
    resetViaPtr(&c);
    return x + c.x;             // warn, maybe null
}

int f4b(const C c, const C d)
{
    if (!c || !d)
        return 42;
    return c.x + d.x;
}

int f6a(const C c)
{
    if (c.x && c)               // error
        return c.x;
    return 0;
}

int f6b(const C c)
{
    if (c && c.x)
        return c.x;
    return 0;
}

int f10c(const C c)
{
    if (c is null)
        return c.x;             // error
    return 0;
}

int f0(const C c)
{
    assert(c);
    return c.x;                 // ok with `-debug`
}

int f02(const C c, const C d)
{
    assert(c && d);
    return c.x + d.x;           // ok with `-debug`
}

int f03(const C c, const C d)
{
    assert(c || d);             // insufficient check
    return c.x + d.x;           // warn, maybe null
}

int f2(const C c)
{
    if (c)
        return c.x;
    return c.x;                 // error
}

int f3()
{
    const C c;
    return c.x;                 // error
}

int f4(const C c)
{
    if (c)
        return c.x;
    return 0;
}

int f4a(const C c)
{
    if (!c)
        return 42;
    return c.x;
}

int f4b(const C c)
{
    if (!c)
        return c.x;             // error
    return c.x;
}

int f7(const C c, const C d)
{
    if (c && d)
        return c.x + d.x;
    return 0;
}

int f9(const C c)
{
    if (!c)
        return 0;
    return c.x;
}

int f11()
{
    const C c = new C();
    return c.x;
}

int f12()
{
    const C c = new C();
    const C d = c;
    return d.x;
}

int f13()
{
    C c;
    c = new C();
    return c.x;
}

int f14()
{
    const C c;
    const C d = c;
    return d.x;                 // error
}

void f15()
{
    const C c = new C();
    assert(c);                  // warn, always `true`
}

void f16()
{
    const C c;
    assert(c);                  // warn, always `false`
}
