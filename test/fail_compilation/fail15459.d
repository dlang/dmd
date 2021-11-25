// https://issues.dlang.org/show_bug.cgi?id=15459

/*
TEST_OUTPUT:
---
false
fail_compilation/fail15459.d(25): Error: cannot implicitly convert expression `d` of type `dchar` to `char`
fail_compilation/fail15459.d(31): Error: template instance `fail15459.MapResult!()` error instantiating
fail_compilation/fail15459.d(36):        instantiated from here: `map!()`
---
*/

enum e = is(typeof(map()));

pragma(msg, e);


struct MapResult()
{
    this(char[] a) {}

    char front()
    {
        dchar d;
        return d; /* should fail compilation */
    }
}

void map()()
{
    auto mr = MapResult!()([]);
}

void main()
{
    map();
}
