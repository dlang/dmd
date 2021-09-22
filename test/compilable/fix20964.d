// https://issues.dlang.org/show_bug.cgi?id=20964

uint foo(uint[3] m)
{
    auto p = m.ptr;
    p += 3; // ok, p refers to the next right element after the block!
    p -= 4; // ok, p refers to the next left element before the block!
    p++;
    return *p;
}

static assert(foo([3, 2, 4]) == 3);
