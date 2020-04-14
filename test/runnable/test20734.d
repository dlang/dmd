/*
REQUIRED_ARGS: -betterC -preview=dip1000
*/

int numDtor;

struct S
{
    int a;
    ~this() nothrow @nogc @safe { ++numDtor; }
}

void takeScopeSlice(const scope S[] slice) nothrow @nogc @safe {}

extern(C) int main() nothrow @nogc @safe
{
    takeScopeSlice([ S(1), S(2) ]); // @nogc => no GC allocation
    assert(numDtor == 2); // stack-allocated array literal properly destructed
    return 0;
}
