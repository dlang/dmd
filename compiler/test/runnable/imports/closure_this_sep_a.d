module imports.closure_this_sep_a;

/* `g` is compiled here. Its context pointer kind must be the same one
 * closure_this_sep.d assumes when it instantiates `S.get` and calls `g`
 * from it: a local struct in the method rules `this` out for `g` in both.
 */
class C
{
    int x = 42;
    auto fd()
    {
        int y = 7;
        int h() { return y; }
        int g() { return x; }
        struct S { int pad; int get()() { return g(); } }
        return S(h());
    }
}
