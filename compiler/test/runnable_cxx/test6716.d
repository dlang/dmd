// EXTRA_CPP_SOURCES: test6716.cpp

version(Windows)
{
    // without main, there is no implicit reference to the runtime library
    // other platforms pass the runtime library on the linker command line
    pragma(lib, "druntime");
}

extern(C++) int test6716(int magic)
{
    assert(magic == 12345);
    return 0;
}
