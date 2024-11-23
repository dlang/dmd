/*
TEST_OUTPUT:
---
fail_compilation/test9701.d(88): Error: `@safe` is not a valid attribute for enum members
    @safe safe,
     ^
fail_compilation/test9701.d(89): Error: `@system` is not a valid attribute for enum members
    @system system,
     ^
fail_compilation/test9701.d(90): Error: `@trusted` is not a valid attribute for enum members
    @trusted trusted,
     ^
fail_compilation/test9701.d(91): Error: `@nogc` is not a valid attribute for enum members
    @nogc nogc,
     ^
fail_compilation/test9701.d(92): Error: found `pure` when expecting `identifier`
    pure pure_,
    ^
fail_compilation/test9701.d(93): Error: found `shared` when expecting `identifier`
    shared shared_,
    ^
fail_compilation/test9701.d(94): Error: found `inout` when expecting `identifier`
    inout inout_,
    ^
fail_compilation/test9701.d(95): Error: found `immutable` when expecting `identifier`
    immutable immutable_,
    ^
fail_compilation/test9701.d(96): Error: found `const` when expecting `identifier`
    const const_,
    ^
fail_compilation/test9701.d(97): Error: found `synchronized` when expecting `identifier`
    synchronized synchronized_,
    ^
fail_compilation/test9701.d(98): Error: found `scope` when expecting `identifier`
    scope scope_,
    ^
fail_compilation/test9701.d(99): Error: found `auto` when expecting `identifier`
    auto auto_,
    ^
fail_compilation/test9701.d(100): Error: found `ref` when expecting `identifier`
    ref ref_,
    ^
fail_compilation/test9701.d(101): Error: found `__gshared` when expecting `identifier`
    __gshared __gshared_,
    ^
fail_compilation/test9701.d(102): Error: found `final` when expecting `identifier`
    final final_,
    ^
fail_compilation/test9701.d(103): Error: found `extern` when expecting `identifier`
    extern extern_,
    ^
fail_compilation/test9701.d(104): Error: found `export` when expecting `identifier`
    export export_,
    ^
fail_compilation/test9701.d(105): Error: found `nothrow` when expecting `identifier`
    nothrow nothrow_,
    ^
fail_compilation/test9701.d(106): Error: found `public` when expecting `identifier`
    public public_,
    ^
fail_compilation/test9701.d(107): Error: found `private` when expecting `identifier`
    private private_,
    ^
fail_compilation/test9701.d(108): Error: found `package` when expecting `identifier`
    package package_,
    ^
fail_compilation/test9701.d(109): Error: found `static` when expecting `identifier`
    static static1,
    ^
fail_compilation/test9701.d(110): Error: found `static` when expecting `identifier`
    @("a") static static2,
           ^
fail_compilation/test9701.d(111): Error: found `static` when expecting `identifier`
    static @("a") static3,
    ^
fail_compilation/test9701.d(112): Error: found `static` when expecting `identifier`
    @("a") static @("b") static3,
           ^
---
*/

// This test exists to verify that parsing of enum member attributes rejects invalid attributes

// https://issues.dlang.org/show_bug.cgi?id=9701

enum Enum
{
    @safe safe,
    @system system,
    @trusted trusted,
    @nogc nogc,
    pure pure_,
    shared shared_,
    inout inout_,
    immutable immutable_,
    const const_,
    synchronized synchronized_,
    scope scope_,
    auto auto_,
    ref ref_,
    __gshared __gshared_,
    final final_,
    extern extern_,
    export export_,
    nothrow nothrow_,
    public public_,
    private private_,
    package package_,
    static static1,
    @("a") static static2,
    static @("a") static3,
    @("a") static @("b") static3,
}
