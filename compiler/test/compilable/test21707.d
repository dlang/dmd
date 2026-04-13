// https://github.com/dlang/dmd/issues/21707
// Segfault with -vcg-ast and foreach on a tuple sequence

/+
REQUIRED_ARGS: -vcg-ast -o-
OUTPUT_FILES: compilable/test21707.d.cg
TEST_OUTPUT:
---
foobar(T)
test()
=== compilable/test21707.d.cg
import object;
template TypeTuple(T...)
{
	alias TypeTuple = T;
}
enum foobar(T) = 2;
void test()
{
	/*unrolled*/ {
		{
			alias sym = foobar;
		}
	}
	/*unrolled*/ {
		{
			alias sym = test;
		}
	}
}
---
+/

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
