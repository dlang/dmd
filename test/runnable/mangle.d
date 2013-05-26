// PERMUTE_ARGS:

pragma(mangle, "_test1_") int test1;

static assert(test1.mangleof == "_test1_");

__gshared pragma(mangle, "_test2_") ubyte test2;

static assert(test2.mangleof == "_test2_");

pragma(mangle, "_test3_") void test3()
{
}

static assert(test3.mangleof == "_test3_");

pragma(mangle, "_test6_") __gshared char test6;

static assert(test6.mangleof == "_test6_");

pragma(mangle, "_test7_") @system
{
    void test7()
    {
    }
}

static assert(test7.mangleof == "_test7_");

template getModuleInfo(alias mod)
{
    pragma(mangle, "_D"~mod.mangleof~"12__ModuleInfoZ") static __gshared extern ModuleInfo mi;
    enum getModuleInfo = &mi;
}

void test8()
{
    assert(getModuleInfo!(object).name == "object");
}

//UTF-8 chars
__gshared pragma(mangle, "test_эльфийские_письмена_9") ubyte test9_1;
__gshared extern pragma(mangle, "test_эльфийские_письмена_9") ubyte test9_1_e;

void test9()
{
    test9_1 = 42;
    assert(test9_1_e == 42);
}

void main()
{
    test8();
    test9();
}
