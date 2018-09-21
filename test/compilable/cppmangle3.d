module cppmangle3;

import std.traits : fullyQualifiedName;

extern(C++, "true")
{
}

extern(C++, "__traits")
{
}

extern(C++, "foo")
{
}

int foo; // no name clashing with above namespace

extern(C++, "std", "chrono")
{
    void func();
}

version(Windows) static assert(func.mangleof == "?func@chrono@std@@YAXXZ");
else             static assert(func.mangleof == "_ZNSt6chrono4funcEv");

static assert(fullyQualifiedName!func == "cppmangle3.func");

struct Foo
{
    extern(C++, "namespace")
    {
        static void bar();
    }
}

static assert(is(Alias!(__traits(parent, bar)) == Foo));

