
// Test C++ features.

version(CRuntime_Microsoft)
{
    static assert(__CXXLIB__ == "libcmt");
}
else
{
    static assert(__CXXLIB__.length == 0);
}
