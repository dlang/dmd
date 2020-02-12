version(Windows)
{
    extern (C++, std)
    {
        struct char_traits(Char)
        {
        }
        extern (C++, class) struct basic_string(T, Traits)
        {
        }
        alias test_string = basic_string!(char, char_traits!char);
    }
    extern (C++) void test(ref const(std.test_string) str) {}

    version(D_LP64)
        static assert(test.mangleof == "?test@@YAXAEBV?$basic_string@DU?$char_traits@D@std@@@std@@@Z");
    else
    {
        version(CRuntime_DigitalMars)
            static assert(test.mangleof == "?test@@YAXABV?$basic_string@std@DU?$char_traits@std@D@1@@std@@@Z");
        else
            static assert(test.mangleof == "?test@@YAXABV?$basic_string@DU?$char_traits@D@std@@@std@@@Z");
    }
}
