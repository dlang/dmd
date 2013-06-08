// PERMUTE_ARGS:
// REQUIRED_ARGS: -c -Icompilable/extra-files

void test1()
{
    import pkg.datetime;
    def();
}

void test2()
{
    import pkg.datetime;
    def();
    pkg.datetime.common.def();
    pkg.datetime.def();
}

void test3()
{
    import pkg.datetime.common;
    def();
}

void test4()
{
    import pkg.datetime : def;
    def();
}


void test7()
{
    static import pkg.datetime;
    static assert(!__traits(compiles, def()));
    pkg.datetime.def();
}

