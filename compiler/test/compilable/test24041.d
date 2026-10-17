// https://github.com/dlang/dmd/issues/24041
// A struct whose semantic finishes inside a gagged analysis that already
// errored must keep its copy constructor.

struct Handle(T)
{
    int* count;
    this(ref return scope inout Handle rhs) inout
    {
        count = rhs.count;
    }
}

// Not `inout`: Outer's generated `inout` copy constructor fails to compile
// (a gagged error) ...
struct MutOnlyCopy
{
    int x;
    this(ref MutOnlyCopy rhs) { x = rhs.x; }
}

// ... and analysing it reaches Lazy, so Handle!int (first used by Lazy)
// finishes its semantic under that error.
struct Outer
{
    MutOnlyCopy m;
    Lazy l;
}

final class Lazy { Handle!int h; }

static assert(__traits(hasCopyConstructor, Handle!int));
