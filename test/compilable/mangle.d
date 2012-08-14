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
