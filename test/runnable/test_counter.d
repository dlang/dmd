module test_counter;

void test1()
{
    static foreach(i; 0 .. 2)
    {
        static if (!is(typeof(baseCounter)))
            enum baseCounter = __COUNTER__;
        static assert(__COUNTER__ == baseCounter + i + 1);
    }
}

void test2()
{
    enum baseCounter = __COUNTER__;
    static assert(__COUNTER__ == baseCounter + 1);
    static assert(__COUNTER__ == baseCounter + 2);
}

void test3()
{
    const baseCounter = __COUNTER__;
    // here foreach would create temp, so it cant be used
    for (auto i = 0; i < 3; i++)
        // __COUNTER__ is a CTexpr so it's does not change here
        assert(__COUNTER__ == baseCounter + 1);
}

void test4()
{
    mixin(`enum uID = "myVar`, __COUNTER__, `";`);
    mixin("int ", uID, " = 42;");
    mixin("assert(", uID, " == 42);");
}

void test5()
{
    int i;
    static assert(__traits(compiles, i = __COUNTER__));
    static assert(!__traits(compiles, __COUNTER__ = i));
}

void main()
{
    test3();
    test4();
}
