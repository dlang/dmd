/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `int += float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `int -= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `int *= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `int /= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `int %= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `uint += float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `uint -= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `uint *= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `uint /= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `uint %= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `long += float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `long -= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `long *= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `long /= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `long %= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `long += double` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `long -= double` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `long *= double` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `long /= double` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `long %= double` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `ulong += float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `ulong -= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `ulong *= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `ulong /= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `ulong %= float` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `ulong += double` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `ulong -= double` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `ulong *= double` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `ulong /= double` is performing truncating conversion
fail_compilation/failexpression3.d-mixin-50(50): Deprecation: `ulong %= double` is performing truncating conversion
fail_compilation/failexpression3.d(60): Error: template instance `failexpression3.X!(integral, floating, arith)` error instantiating
fail_compilation/failexpression3.d(65):        instantiated from here: `OpAssignCases!(TestOpAssignAuto)`
---
*/
template TT(T...) { alias T TT; }

void TestOpAssignAuto(Tx, Ux, ops)()
{
    foreach(T; Tx.x)
    foreach(U; Ux.x)
    static if (U.sizeof <= T.sizeof)
    foreach(op; ops.x)
    {
        T a = cast(T)1;
        U b = cast(U)1;
        mixin("auto r = a " ~ op ~ " cast(U)1;");
    }
}

struct integral  { alias TT!(byte, ubyte, short, ushort, int, uint, long, ulong) x; }
struct floating  { alias TT!(float, double, real) x; }
struct arith     { alias TT!("+=", "-=", "*=", "/=", "%=") x; }

void OpAssignCases(alias X)()
{
    X!(integral, floating, arith)();
}

void main()
{
    OpAssignCases!TestOpAssignAuto(); // https://issues.dlang.org/show_bug.cgi?id=5181
}
