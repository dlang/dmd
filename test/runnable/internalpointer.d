/** Container with internal pointer
 */
struct Container
{
    long[1] data;
    void* p;

    static size_t errors;

    this(int) { p = &data[0]; }
    this(ref Container) { p = &data[0]; }
    this(this) { p = &data[0]; }

    /** Ensure the internal pointer is correct */
    void check(int line = __LINE__, string file = __FILE__)()
    {
        if (p != &data[0])
        {
            import core.stdc.stdio : printf;
            printf("%s(%d): %s\n", file.ptr, line, "error".ptr);
            ++errors;
        }
    }
}

void main()
{
    Container v = Container(1);
    v.check(); // ok

    auto p = new Container(1);
    p.check();

    func(v);

    auto r = get();
    r.check(); // error

    Container[1] slit = [v];
    slit[0].check(); // error

    Container[] dlit = [v];
    dlit[0].check(); // error

    Container[] darr;
    darr ~= v;
    darr[0].check(); // error

    auto b = B(v);
    b.m.check(); // error

    func(Container(1));
    func(getInt, v);

    getRef(v).check(); // error

    Container[int] aa = [1: v];
    aa[1].check(); // error

    assert(!Container.errors);
}

void func(Container c) { c.check(); } // error
extern(C++) void func(int, Container c) { c.check(); } // error

Container get()
out(r; 1)
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

ref Container getRef(return ref Container v)
{
    v.check(); // ok
    return getF().flag ? v : v;
}

int getInt() { return 0; }

F getF() { return F(); }

struct B
{
    Container m;
}

struct F
{
    bool flag;
    ~this(){}
}
