/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a + 1.0F` of type `float` to `int`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a - 1.0F` of type `float` to `int`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a * 1.0F` of type `float` to `int`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a / 1.0F` of type `float` to `int`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a % 1.0F` of type `float` to `int`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a + 1.0F` of type `float` to `uint`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a - 1.0F` of type `float` to `uint`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a * 1.0F` of type `float` to `uint`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a / 1.0F` of type `float` to `uint`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a % 1.0F` of type `float` to `uint`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a + 1.0F` of type `float` to `long`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a - 1.0F` of type `float` to `long`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a * 1.0F` of type `float` to `long`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a / 1.0F` of type `float` to `long`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a % 1.0F` of type `float` to `long`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(double)a + 1.0` of type `double` to `long`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(double)a - 1.0` of type `double` to `long`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(double)a * 1.0` of type `double` to `long`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(double)a / 1.0` of type `double` to `long`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(double)a % 1.0` of type `double` to `long`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a + 1.0F` of type `float` to `ulong`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a - 1.0F` of type `float` to `ulong`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a * 1.0F` of type `float` to `ulong`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a / 1.0F` of type `float` to `ulong`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(float)a % 1.0F` of type `float` to `ulong`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(double)a + 1.0` of type `double` to `ulong`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(double)a - 1.0` of type `double` to `ulong`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(double)a * 1.0` of type `double` to `ulong`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(double)a / 1.0` of type `double` to `ulong`
fail_compilation/failexpression4.d-mixin-50(50): Error: cannot implicitly convert expression `cast(double)a % 1.0` of type `double` to `ulong`
fail_compilation/failexpression4.d(60): Error: template instance `failexpression4.X!(integral, floating, arith)` error instantiating
fail_compilation/failexpression4.d(65):        instantiated from here: `OpReAssignCases!(TestOpAndAssign)`
---
*/
template TT(T...) { alias T TT; }

void TestOpAndAssign(Tx, Ux, ops)()
{
    foreach(T; Tx.x)
    foreach(U; Ux.x)
    static if (U.sizeof <= T.sizeof && T.sizeof >= 4)
    foreach(op; ops.x)
    {
        T a = cast(T)1;
        U b = cast(U)1;
        mixin("a = a " ~ op[0..$-1] ~ " cast(U)1;");
    }
}

struct integral  { alias TT!(byte, ubyte, short, ushort, int, uint, long, ulong) x; }
struct floating  { alias TT!(float, double, real) x; }
struct arith     { alias TT!("+=", "-=", "*=", "/=", "%=") x; }

void OpReAssignCases(alias X)()
{
    X!(integral, floating, arith)();
}

void main()
{
    OpReAssignCases!TestOpAndAssign();
}
