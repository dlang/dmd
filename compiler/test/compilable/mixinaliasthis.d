mixin template M { this(int x) { } }
mixin template N { this(string s) { } }

struct S
{
    mixin m = M;
    mixin n = N;
    this(int x, string s) { }
    alias
        this = m.this,
        this = n.this;
}

void f()
{
    S s = S(10), t = S("abc");
}
