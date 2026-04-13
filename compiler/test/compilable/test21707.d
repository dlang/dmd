// https://github.com/dlang/dmd/issues/21707
// Segfault with -vcg-ast and foreach on a tuple sequence

/*
REQUIRED_ARGS: -vcg-ast -o-
OUTPUT_FILES: compilable/test21707.d.cg
TEST_OUTPUT:
---
foobar(T)
test()
---
*/

template TypeTuple(T...)
{
    alias TypeTuple = T;
}

template foobar(T)
{
    enum foobar = 2;
}

void test()
{
    foreach (sym; TypeTuple!(foobar))
        pragma(msg, sym.stringof);

    foreach (sym; TypeTuple!(test))
        pragma(msg, sym.stringof);
}
