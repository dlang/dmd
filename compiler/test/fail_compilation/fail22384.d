/*
TEST_OUTPUT:
---
fail_compilation/fail22384.d(36): Error: bitfield `z` cannot have zero width
fail_compilation/fail22384.d(40): Error: bitfield `f` cannot be of non-integral type `float`
fail_compilation/fail22384.d(41): Error: bitfield `f2` cannot be of non-integral type `float`
fail_compilation/fail22384.d(42): Error: bitfield `f3` cannot be of non-integral type `float`
fail_compilation/fail22384.d(43): Error: bitfield `f4` cannot be of non-integral type `float`
fail_compilation/fail22384.d(48): Error: anonymous bitfield cannot have default initializer
fail_compilation/fail22384.d(25): Error: default initializer `4294967295u` is not representable as bitfield type `uint:4`
fail_compilation/fail22384.d(25):        bitfield `d` default initializer must be a value between `0..15`
fail_compilation/fail22384.d(30): Error: default initializer `E.B` is not representable as bitfield type `int:2`
fail_compilation/fail22384.d(30):        bitfield `b` default initializer must be a value between `-2..1`
fail_compilation/fail22384.d(34): Error: default initializer `4` is not representable as bitfield type `int:3`
fail_compilation/fail22384.d(34):        bitfield `x` default initializer must be a value between `-4..3`
fail_compilation/fail22384.d(35): Error: default initializer `65` is not representable as bitfield type `int:7`
fail_compilation/fail22384.d(35):        bitfield `y` default initializer must be a value between `-64..63`
fail_compilation/fail22384.d(47): Error: cannot implicitly convert expression `4.2F` of type `float` to `int`
fail_compilation/fail22384.d(49): Error: default initializer `65` is not representable as bitfield type `int:7`
fail_compilation/fail22384.d(49):        bitfield `j` default initializer must be a value between `-64..63`
fail_compilation/fail22384.d(50): Error: cannot implicitly convert expression `42` of type `int` to `bool`
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
