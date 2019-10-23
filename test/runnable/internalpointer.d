/** Container with internal pointer
 * bugzilla: https://issues.dlang.org/show_bug.cgi?id=20321
 */
struct Container
{
    long[3] data;
    void* p;

    this(int) { p = &data[0]; }
    this(ref Container) { p = &data[0]; }

    /** Ensure the internal pointer is correct */
    void check(int line = __LINE__, string file = __FILE__)()
    {
        if (p != &data[0])
        {
            import core.stdc.stdio : printf;
            printf("%s(%d): %s\n", file.ptr, line, "error".ptr);
        }
    }
}

void func(Container c) { c.check(); } // error

Container get()
{
    auto a = Container(1);
    auto b = a;
    a.check(); // ok
    b.check(); // ok
    // no nrvo
    if (1)
        return a;
    else
        return b;
}

void main()
{
    Container v = Container(1);
    v.check(); // ok

    func(v);
    auto r = get();
    r.check(); // error

    Container[1] slit = [v];
    slit[0].check(); // error

    Container[] dlit = [v];
    dlit[0].check(); // error

    auto b = B(v);
    b.m.check(); // error
}

struct B
{
    Container m;
}
