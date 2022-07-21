/* REQUIRED_ARGS: -preview=dip1000
 */

// https://issues.dlang.org/show_bug.cgi?id=23260

struct S { int* p; this(int* p) { } }

@safe test()
{
    int a;
    S s = S(&a);  // ctor attribute inference will let this compile
}

struct T
{
    string[] tags;

    this(string[] tags...)
    {
        this.tags = tags; // don't infer `return` attribute for `tags`
    }
}
