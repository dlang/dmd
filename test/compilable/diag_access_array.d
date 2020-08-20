// REQUIRED_ARGS: -wi -unittest -diagnose=access -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_array.d(30): Warning: returned expression is always `null`
compilable/diag_access_array.d(28): Warning: unused local constant `x` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_array.d(37): Warning: returned expression is always `null`
compilable/diag_access_array.d(28): Warning: unused local constant `x` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_array.d(56): Warning: unused local constant `x` of function, remove, rename to `_` or prepend `_` to name to silence
---
*/

int f1()
{
    const(int)[2] x;
    return x[0];                // partial
}

int f2()
{
    const(int)[1] x;
    return x[0];                // full
}

const(int)[] f3()
{
    const int[] x;              // warn
    const int[] y;
    return y;
}

const(int)[] f4()
{
    const int[] x;
    const int[] y = x;          // read here
    return y;
}

const(int)[] f5()
{
    const int[] x;
    const int[] y = x[0 .. $];  // read here
    return y;
}

const(int)[] f6()
{
    const int[] x;
    const int[] y = x[];        // read here
    return y;
}

const(int)[1] f7()
{
    const(int)[1] x;            // warn
    const(int)[1] y;
    return y;
}

const(int)[1] f8()
{
    const(int)[1] x;
    const(int)[1] y = x;
    return y;
}

const(int)[1] f9()
{
    const(int)[2] x;
    const(int)[1] y = x[0 .. 1];
    return y;
}
