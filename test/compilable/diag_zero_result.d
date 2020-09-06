// REQUIRED_ARGS:

/*
TEST_OUTPUT:
---
compilable/diag_zero_result.d(30): Deprecation: cast from `idouble` to `byte` will produce zero result
compilable/diag_zero_result.d(31): Deprecation: cast from `idouble` to `short` will produce zero result
compilable/diag_zero_result.d(32): Deprecation: cast from `idouble` to `int` will produce zero result
compilable/diag_zero_result.d(33): Deprecation: cast from `idouble` to `long` will produce zero result
compilable/diag_zero_result.d(34): Deprecation: cast from `idouble` to `float` will produce zero result
compilable/diag_zero_result.d(35): Deprecation: cast from `idouble` to `double` will produce zero result
compilable/diag_zero_result.d(36): Deprecation: cast from `idouble` to `real` will produce zero result
compilable/diag_zero_result.d(42): Deprecation: cast from `double` to `ifloat` will produce zero result
compilable/diag_zero_result.d(43): Deprecation: cast from `double` to `idouble` will produce zero result
compilable/diag_zero_result.d(44): Deprecation: cast from `double` to `ireal` will produce zero result
compilable/diag_zero_result.d(50): Deprecation: cast from `float` to `ifloat` will produce zero result
compilable/diag_zero_result.d(51): Deprecation: cast from `float` to `idouble` will produce zero result
compilable/diag_zero_result.d(52): Deprecation: cast from `float` to `ireal` will produce zero result
compilable/diag_zero_result.d(58): Deprecation: cast from `real` to `ifloat` will produce zero result
compilable/diag_zero_result.d(59): Deprecation: cast from `real` to `idouble` will produce zero result
compilable/diag_zero_result.d(60): Deprecation: cast from `real` to `ireal` will produce zero result
compilable/diag_zero_result.d(78): Deprecation: cast from `R` to `I` will produce zero result
compilable/diag_zero_result.d(85): Deprecation: cast from `I` to `R` will produce zero result
---
*/

@safe pure test1()
{
    idouble id = 2.0i;
    const b = cast(byte)id;
    const s = cast(short)id;
    const i = cast(int)id;
    const l = cast(long)id;
    const f = cast(float)id;
    const d = cast(double)id;
    const r = cast(real)id;
}

@safe pure test2()
{
    double d = 2.0;
    const fi = cast(ifloat)d;
    const di = cast(idouble)d;
    const ri = cast(ireal)d;
}

@safe pure test3()
{
    float d = 2.0;
    const fi = cast(ifloat)d;
    const di = cast(idouble)d;
    const ri = cast(ireal)d;
}

@safe pure test4()
{
    real d = 2.0;
    const fi = cast(ifloat)d;
    const di = cast(idouble)d;
    const ri = cast(ireal)d;
}

enum R : double
{
    one = 1.0,
    two = 2.0,
}

enum I : idouble
{
    one = 1.0i,
    two = 2.0i,
}

@safe pure testEnumRI()
{
    R r = R.one;
    I i = cast(I)r;
    assert(i == 0);
}

@safe pure testEnumIR()
{
    I i = I.one;
    R r = cast(R)i;
    assert(r == 0);
}
