#include "array.h"
#include <cassert>

void ints(DSlice<int> values)
{
    assert(values.length == 1);
    assert(values.ptr[0] == 1);
}

void cints(DSlice<const int> a)
{
    assert(a.length == 2);
    assert(a.ptr[0] == 2);
    assert(a.ptr[1] == 3);
}

void ccints(const DSlice<const int> a)
{
    assert(a.length == 3);
    assert(a.ptr[0] == 4);
    assert(a.ptr[1] == 5);
    assert(a.ptr[2] == 6);
}

DSlice<int> wrap(int* ptr, int size)
{
    return DSlice<int>(size, ptr);
}

void paddedInts(signed char d1, DSlice<int> a, short d2, DSlice<int> b)
{
    assert(d1 == 33);

    assert(a.length == 1);
    assert(*a.ptr == 44);

    assert(d2 == 55);

    assert(b.length == 1);
    assert(*b.ptr == 66);
}

DSlice<char> passthrough(DSlice<char> values)
{
    assert(values.length == 5);
    return values;
}

DSlice<char>& passthroughRef(DSlice<char>& values)
{
    assert(values.length == 5);
    return values;
}

struct S
{
    int a, b;
};

void structs(DSlice<S> values)
{
    assert(values.length == 1);
    assert(values.ptr->a == 1);
    assert(values.ptr->b == 2);
}

