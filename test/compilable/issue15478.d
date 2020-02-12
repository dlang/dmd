// https://issues.dlang.org/show_bug.cgi?id=15478
// CTFE on exp giving the dims not run on paren-less funcs

void test1()
{
    struct Foo(N)
    {
        this(N value) { }
        static int bug() { return 0; }
    }
    enum Foo!int foo = 0;
    Foo!int[foo.bug] bar;
}

void test2()
{
    int getLength()  { return 42; }
    struct Get {static int length() { return 42; }}

    int[getLength]  i1;
    int[Get.length] i2;
    static assert (is(typeof(i1) == int[42]));
    static assert (is(typeof(i2) == int[42]));
}

