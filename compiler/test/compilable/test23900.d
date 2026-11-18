// https://github.com/dlang/dmd/issues/23900
struct S
{
    int a;
    int b;
}

void test()
{
    int[3][2] color = [1: [255, 0, 0]];
    assert(color[0] == [0, 0, 0]);
    assert(color[1] == [255, 0, 0]);

    S[][] x = [[{a: 1}], [1: {b: 2}, {}]];
    assert(x[0][0] == S(1, 0));
    assert(x[1][0] == S(0, 0));
    assert(x[1][1] == S(0, 2));

    S[2][] y = [[{}, {1, 2}], []];
    assert(y[0][1] == S(1, 2));
    assert(y[1] == [S(0, 0), S(0, 0)]);

    int[2][3] z = 7;
    assert(z[2] == [7, 7]);

    static immutable S[] w = [{a: 3}, 3: {b: 4}];
    static assert(w.length == 4);
    static assert(w[3].b == 4);
}

static assert({ test(); return true; }());

// dyaml's regexes table: mutable call results in an immutable array literal
// must be interpreted before the conversion, not cast per element
struct R
{
    int[] a;
}

R make(int x)
{
    return R([x]);
}

immutable R[] rs = [make(1), make(2)];
static assert(rs[1].a[0] == 2);
