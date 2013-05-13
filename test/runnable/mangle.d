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

//spaces
__gshared pragma(mangle, "test 9") ubyte test9_1;
__gshared extern pragma(mangle, "test 9") ubyte test9_1_e;

//\n chars
__gshared pragma(mangle, "test\n9") ubyte test9_2;
__gshared extern pragma(mangle, "test\n9") ubyte test9_2_e;

//\a chars
__gshared pragma(mangle, "test\a9") ubyte test9_3;
__gshared extern pragma(mangle, "test\a9") ubyte test9_3_e;

//\x01 chars
__gshared pragma(mangle, "test\x019") ubyte test9_4;
__gshared extern pragma(mangle, "test\x019") ubyte test9_4_e;

//\0 chars
__gshared pragma(mangle, "test\09") ubyte test9_5;
__gshared extern pragma(mangle, "test\09") ubyte test9_5_e;

//\xff chars
__gshared pragma(mangle, "test\xff9") ubyte test9_6;
__gshared extern pragma(mangle, "test\xff9") ubyte test9_6_e;

//UTF-8 chars
__gshared pragma(mangle, "test_эльфийские_письмена_9") ubyte test9_7;
__gshared extern pragma(mangle, "test_эльфийские_письмена_9") ubyte test9_7_e;

void test10()
{
    test9_1 = 42;
    assert(test9_1_e == 42);
    
    test9_2 = 42;
    assert(test9_2_e == 42);
    
    test9_3 = 42;
    assert(test9_3_e == 42);
    
    test9_4 = 42;
    assert(test9_4_e == 42);
    
    test9_5 = 42;
    assert(test9_5_e == 42);
    
    test9_6 = 42;
    assert(test9_6_e == 42);

    test9_7 = 42;
    assert(test9_7_e == 42);     
}

void main()
{
    test8();
    test10();
}
