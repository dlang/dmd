// DISABLED: win32
// REQUIRED_ARGS: -extern-std=c++11
// EXTRA_CPP_SOURCES: cpp11.cpp
// CXXFLAGS: -std=c++11

// Disabled on win32 because the compiler is too old

/****************************************/
alias nullptr_t = typeof(null);

// Only run on OSX/Win64 because the compilers are too old
// and nullptr_t gets substituted
version (FreeBSD)
    version = IgnoreNullptrTest;
version (linux)
    version = IgnoreNullptrTest;

version (IgnoreNullptrTest) { void test17() {} }
else
{
    extern (C++) void testnull(nullptr_t);
    extern (C++) void testnullnull(nullptr_t, nullptr_t);

    void test17()
    {
        testnull(null);
        testnullnull(null, null);
    }
}

void main()
{
    test17();
}
