

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


