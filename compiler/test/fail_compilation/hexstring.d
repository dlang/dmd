/**
TEST_OUTPUT:
---
fail_compilation/hexstring.d(55): Error: cannot implicitly convert expression `"123F"` of type `string` to `immutable(ubyte[])`
immutable ubyte[] f2 = "123F";
                       ^
fail_compilation/hexstring.d(59): Error: hex string length 1 must be a multiple of 2 to cast to `immutable(ushort[])`
immutable ushort[] f5 = cast(immutable ushort[]) x"11";
                                                 ^
fail_compilation/hexstring.d(60): Error: hex string length 3 must be a multiple of 4 to cast to `immutable(uint[])`
immutable uint[] f6 = cast(immutable uint[]) x"112233";
                                             ^
fail_compilation/hexstring.d(61): Error: hex string length 5 must be a multiple of 8 to cast to `immutable(ulong[])`
immutable ulong[] f7 = cast(immutable ulong[]) x"1122334455";
                                               ^
fail_compilation/hexstring.d(62): Error: array cast from `wstring` to `immutable(ulong[])` is not supported at compile time
immutable ulong[] f8 = cast(immutable ulong[]) x"11223344"w;
                                               ^
fail_compilation/hexstring.d(62):        perhaps remove postfix `w` from hex string
fail_compilation/hexstring.d(63): Error: array cast from `string` to `immutable(uint[])` is not supported at compile time
immutable uint[] f9 = cast(immutable uint[]) "ABCD";
                                             ^
fail_compilation/hexstring.d(64): Error: array cast from `string` to `immutable(ushort[])` is not supported at compile time
immutable ushort[] f10 = cast(immutable ushort[]) (x"1122" ~ "");
                                                   ^
fail_compilation/hexstring.d(65): Error: array cast from `string` to `immutable(uint[])` is not supported at compile time
immutable uint[] f11 = cast(immutable uint[]) x"AABBCCDD"c;
                                              ^
fail_compilation/hexstring.d(65):        perhaps remove postfix `c` from hex string
fail_compilation/hexstring.d(66): Error: hex string with `dstring` type needs to be multiple of 4 bytes, not 5
immutable uint[] f12 = x"1122334455"d;
                       ^
fail_compilation/hexstring.d(67): Error: cannot implicitly convert expression `x"11223344"d` of type `dstring` to `immutable(float[])`
immutable float[] f13 = x"11223344"d;
                        ^
fail_compilation/hexstring.d(68): Error: cannot implicitly convert expression `x"1122"w` of type `wstring` to `immutable(ubyte[])`
immutable ubyte[] f14 = x"1122"w;
                        ^
fail_compilation/hexstring.d(76): Error: array cast from `string` to `S[]` is not supported at compile time
immutable S[] returnValues = cast(S[]) x"FFFFFFFFFFFFFFFFFFFFFFFF";
                                       ^
fail_compilation/hexstring.d(54): Error: cannot implicitly convert expression `x"123F"` of type `string` to `ubyte[]`
ubyte[] f1 = x"123F";
             ^
---
*/
immutable ubyte[] s0 = x"123F";
static assert(s0[0] == 0x12);
static assert(s0[1] == 0x3F);
immutable byte[] s1 = x"123F";
enum E(X) = cast(X[]) x"AABBCCDD";
static assert(E!int[0] == 0xAABBCCDD);

ubyte[] f1 = x"123F";
immutable ubyte[] f2 = "123F";
immutable ubyte[] f3 = x"123F"c;
immutable ubyte[] f4 = cast(string) x"123F";

immutable ushort[] f5 = cast(immutable ushort[]) x"11";
immutable uint[] f6 = cast(immutable uint[]) x"112233";
immutable ulong[] f7 = cast(immutable ulong[]) x"1122334455";
immutable ulong[] f8 = cast(immutable ulong[]) x"11223344"w;
immutable uint[] f9 = cast(immutable uint[]) "ABCD";
immutable ushort[] f10 = cast(immutable ushort[]) (x"1122" ~ "");
immutable uint[] f11 = cast(immutable uint[]) x"AABBCCDD"c;
immutable uint[] f12 = x"1122334455"d;
immutable float[] f13 = x"11223344"d;
immutable ubyte[] f14 = x"1122"w;

// https://issues.dlang.org/show_bug.cgi?id=24832
struct S
{
    ushort l0, l1, l2, l3, l4, l5;
}

immutable S[] returnValues = cast(S[]) x"FFFFFFFFFFFFFFFFFFFFFFFF";
