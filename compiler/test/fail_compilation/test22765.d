// https://issues.dlang.org/show_bug.cgi?id=22765

/*
TEST_OUTPUT:
---
fail_compilation/test22765.d(16): Error: template instance `test22765.Template!null` internal compiler error: C++ `null` template value parameter is not supported
auto x = Template!(null);
         ^
---
*/

template Template(T...)
{
    extern(C++) const __gshared int Template = 0;
}
auto x = Template!(null);
