import core.stdcpp.memory;

unittest
{
    import core.lifetime : move;

    unique_ptr!int up;
    assert(!up);
    assert(up.get == null);

    auto up2 = make_unique!int(10);
    assert(!!up2);
    assert(up2.get != null);
    assert(*up2.get == 10);

    static assert(!__traits(compiles, up = up2));
    static assert(!__traits(compiles, unique_ptr!int(up)));

    unique_ptr!int x = up2.move;
    assert(!!x && !up2);

    up = x.move;
    assert(!!up && !x);

    int* p = up.get;
    up = passThrough(up.move);
    assert(up.get == p);
    up = changeIt(up.move);
    assert(up.get != p);
    assert(*up.get == 20);

    up.reset();
    assert(!up);
}

extern(C++):

unique_ptr!int passThrough(unique_ptr!int x);
unique_ptr!int changeIt(unique_ptr!int x);
