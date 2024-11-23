/*
TEST_OUTPUT:
---
fail_compilation/fail_circular2.d(20): Error: circular initialization of variable `fail_circular2.S.d1`
    static const int d1 = S.d1;     // CTFE error (expression type is determined to int)
                          ^
fail_compilation/fail_circular2.d(22): Error: circular initialization of variable `fail_circular2.S.e1`
    enum int e1 = S.e1;             // CTFE error
                  ^
fail_compilation/fail_circular2.d(27): Error: circular initialization of variable `fail_circular2.C.d1`
    static const int d1 = C.d1;     // CTFE error
                          ^
fail_compilation/fail_circular2.d(29): Error: circular initialization of variable `fail_circular2.C.e1`
    enum int e1 = C.e1;             // CTFE error
                  ^
---
*/
struct S
{
    static const int d1 = S.d1;     // CTFE error (expression type is determined to int)

    enum int e1 = S.e1;             // CTFE error
}

class C
{
    static const int d1 = C.d1;     // CTFE error

    enum int e1 = C.e1;             // CTFE error
}
