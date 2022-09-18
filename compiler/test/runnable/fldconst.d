// no debug info (adds stack frame), no optimizations (might remove truncation)
// PERMUTE_ARGS:

enum M_PI_L        = 0x1.921fb54442d1846ap+1L;       // 3.14159 fldpi
enum M_LOG2T_L     = 0x1.a934f0979a3715fcp+1L;       // 3.32193 fldl2t
enum M_LOG2E_L     = 0x1.71547652b82fe178p+0L;       // 1.4427 fldl2e
enum M_LOG2_L      = 0x1.34413509f79fef32p-2L;       // 0.30103 fldlg2
enum M_LN2_L       = 0x1.62e42fefa39ef358p-1L;       // 0.693147 fldln2

// verify the first instruction in function fun is the correct opcode
void verify(T, T v, ubyte op)(T x)
{
    static T fun() { return v; }
    T f = fun();
    assert(f == x); // to!string(x) ~ " " ~ to!string(f - x));
    static assert(fun() == v);
    auto fn = &fun;
    auto s = *cast(ushort*) fn;
    ushort expected = (op << 8) | 0xd9;

    assert(s == expected); //, T.stringof ~ " " ~ to!string(v) ~ " " ~ to!string(s, 16) ~ " " ~ to!string(expected, 16));
}

immutable ubyte[7] opcode =
[
    /* FLDZ,FLD1,FLDPI,FLDL2T,FLDL2E,FLDLG2,FLDLN2 */
    0xEE,0xE8,0xEB,0xE9,0xEA,0xEC,0xED
];

void verifyType(T)()
{
    static immutable T[7] ldval = [0.0,1.0,M_PI_L,M_LOG2T_L,M_LOG2E_L,M_LOG2_L,M_LN2_L];
    static foreach(i, v; ldval)
        verify!(T, ldval[i], opcode[i])(ldval[i]);
}

void main()
{
    version(OSX) {} // always has a stack frame
    else version(DigitalMars) version(X86)
    {
        verifyType!(float);
        verifyType!(double);
        verifyType!(real);
    }
}
