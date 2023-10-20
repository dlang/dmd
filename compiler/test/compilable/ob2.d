// REQUIRED_ARGS: -preview=dip1021

void* malloc();

@live T* foo1(T)(T* p)
{
    return p;   // consumes owner
}

@live T* foo2(T)()
{
    T* p = null;
    return p;      // consumes owner
}

@live T* foo3(T)(T* p)
{
    scope T* q = p;  // borrows from p
    return p;          // use of p ends borrow in q
}

@live T* foo4(T)(T* p)
{
    scope T* bq = p;          // borrow
    scope const T* cq = p;    // const borrow
    return p;                   // ends both borrows
}

@live T* foo5(T)()
{
    auto p = cast(T*) malloc();
    scope b = p;
    return p;
}

void test()
{
    int* p;
    foo1!int(p);
    foo2!int();
    foo3!int(p);
    foo4!int(p);
    foo5!int();
}
