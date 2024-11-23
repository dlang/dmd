/*
REQUIRED_ARGS: -de -revert=intpromote
TEST_OUTPUT:
---
fail_compilation/fail16997.d(67): Deprecation: integral promotion not done for `~c`, remove '-revert=intpromote' switch or `~cast(int)(c)`
    x = ~c;
        ^
fail_compilation/fail16997.d(68): Deprecation: integral promotion not done for `-c`, remove '-revert=intpromote' switch or `-cast(int)(c)`
    x = -c;
        ^
fail_compilation/fail16997.d(69): Deprecation: integral promotion not done for `+c`, remove '-revert=intpromote' switch or `+cast(int)(c)`
    x = +c;
        ^
fail_compilation/fail16997.d(72): Deprecation: integral promotion not done for `~w`, remove '-revert=intpromote' switch or `~cast(int)(w)`
    x = ~w;
        ^
fail_compilation/fail16997.d(73): Deprecation: integral promotion not done for `-w`, remove '-revert=intpromote' switch or `-cast(int)(w)`
    x = -w;
        ^
fail_compilation/fail16997.d(74): Deprecation: integral promotion not done for `+w`, remove '-revert=intpromote' switch or `+cast(int)(w)`
    x = +w;
        ^
fail_compilation/fail16997.d(77): Deprecation: integral promotion not done for `~sb`, remove '-revert=intpromote' switch or `~cast(int)(sb)`
    x = ~sb;
        ^
fail_compilation/fail16997.d(78): Deprecation: integral promotion not done for `-sb`, remove '-revert=intpromote' switch or `-cast(int)(sb)`
    x = -sb;
        ^
fail_compilation/fail16997.d(79): Deprecation: integral promotion not done for `+sb`, remove '-revert=intpromote' switch or `+cast(int)(sb)`
    x = +sb;
        ^
fail_compilation/fail16997.d(82): Deprecation: integral promotion not done for `~ub`, remove '-revert=intpromote' switch or `~cast(int)(ub)`
    x = ~ub;
        ^
fail_compilation/fail16997.d(83): Deprecation: integral promotion not done for `-ub`, remove '-revert=intpromote' switch or `-cast(int)(ub)`
    x = -ub;
        ^
fail_compilation/fail16997.d(84): Deprecation: integral promotion not done for `+ub`, remove '-revert=intpromote' switch or `+cast(int)(ub)`
    x = +ub;
        ^
fail_compilation/fail16997.d(87): Deprecation: integral promotion not done for `~s`, remove '-revert=intpromote' switch or `~cast(int)(s)`
    x = ~s;
        ^
fail_compilation/fail16997.d(88): Deprecation: integral promotion not done for `-s`, remove '-revert=intpromote' switch or `-cast(int)(s)`
    x = -s;
        ^
fail_compilation/fail16997.d(89): Deprecation: integral promotion not done for `+s`, remove '-revert=intpromote' switch or `+cast(int)(s)`
    x = +s;
        ^
fail_compilation/fail16997.d(92): Deprecation: integral promotion not done for `~us`, remove '-revert=intpromote' switch or `~cast(int)(us)`
    x = ~us;
        ^
fail_compilation/fail16997.d(93): Deprecation: integral promotion not done for `-us`, remove '-revert=intpromote' switch or `-cast(int)(us)`
    x = -us;
        ^
fail_compilation/fail16997.d(94): Deprecation: integral promotion not done for `+us`, remove '-revert=intpromote' switch or `+cast(int)(us)`
    x = +us;
        ^
---
*/

void test()
{
    int x;

    char c;
    x = ~c;
    x = -c;
    x = +c;

    wchar w;
    x = ~w;
    x = -w;
    x = +w;

    byte sb;
    x = ~sb;
    x = -sb;
    x = +sb;

    ubyte ub;
    x = ~ub;
    x = -ub;
    x = +ub;

    short s;
    x = ~s;
    x = -s;
    x = +s;

    ushort us;
    x = ~us;
    x = -us;
    x = +us;
}
