/*
TEST_OUTPUT:
---
fail_compilation/fail22384.d(32): Error: bitfield `z` has zero width
fail_compilation/fail22384.d(36): Error: bitfield type `float` is not an integer type
fail_compilation/fail22384.d(36): Error: bitfield `f` has zero width
fail_compilation/fail22384.d(37): Error: bitfield type `float` is not an integer type
fail_compilation/fail22384.d(38): Error: bitfield type `float` is not an integer type
fail_compilation/fail22384.d(39): Error: bitfield type `float` is not an integer type
fail_compilation/fail22384.d(44): Error: anonymous bitfield cannot have default initializer
fail_compilation/fail22384.d(21): Error: bitfield initializer `4294967295u` does not fit in 4 bits
fail_compilation/fail22384.d(26): Error: bitfield initializer `E.B` does not fit in 2 bits
fail_compilation/fail22384.d(30): Error: bitfield initializer `4` does not fit in 3 bits
fail_compilation/fail22384.d(31): Error: bitfield initializer `65` does not fit in 7 bits
fail_compilation/fail22384.d(43): Error: cannot implicitly convert expression `4.2F` of type `float` to `int`
fail_compilation/fail22384.d(45): Error: bitfield initializer `65` does not fit in 7 bits
fail_compilation/fail22384.d(46): Error: cannot implicitly convert expression `42` of type `int` to `bool`
---
*/
struct S {
    uint d : 4 = -1;
}

enum E : int { A = 1, B = 2 }
struct EFail {
    E b : 2 = E.B;
}

struct IFail {
    int x : 3 = 4;
    int y : 7 = 65;
    int z : 0 = 1;
}

struct FloatFail {
    float f : 0;
    float f2 : 7;
    float f3 : 7 = 4;
    float f4 : 7 = 4.2f;
}

struct InitFail {
    int i : 7 = 4.2f;
    ubyte : 8 = 4.2f;
    int j : 7 = 'A';
    bool b : 7 = 42;
}
