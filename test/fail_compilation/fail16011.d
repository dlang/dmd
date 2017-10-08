import std.typecons: RefCounted;

struct S
{
    int x;
    RefCounted!S s;
}
