// https://issues.dlang.org/show_bug.cgi?id=22180

align(8) { int x; }
//pragma(msg, x.alignof);
static assert(x.alignof == 8);

// https://github.com/dlang/dmd/issues/20218

struct S
{
    byte i;
    align(1) long a;
    align(2) long b;
    long c;

    void f()
    {
        static assert(a.alignof == 1);
        static assert(this.b.alignof == 2);
    }
}

void foo(S* d, S s)
{
    static assert(d.a.alignof == 1);
    static assert(d.b.alignof == 2);
    static assert(d.c.alignof == long.alignof);
    static assert(s.a.alignof == 1);
}
