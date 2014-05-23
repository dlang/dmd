// REQUIRED_ARGS: -transition=nan
// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
compilable/test12789.d(28): gf is default-initialized with NaN
compilable/test12789.d(29): gd is default-initialized with NaN
compilable/test12789.d(30): gr is default-initialized with NaN
compilable/test12789.d(32): garrf is default-initialized with NaN
compilable/test12789.d(33): garrd is default-initialized with NaN
compilable/test12789.d(34): garrr is default-initialized with NaN
compilable/test12789.d(60): x is default-initialized with NaN
compilable/test12789.d(67): gf is default-initialized with NaN
compilable/test12789.d(68): gd is default-initialized with NaN
compilable/test12789.d(69): gr is default-initialized with NaN
compilable/test12789.d(71): garrf is default-initialized with NaN
compilable/test12789.d(72): garrd is default-initialized with NaN
compilable/test12789.d(73): garrr is default-initialized with NaN
compilable/test12789.d(90): gf is default-initialized with NaN
compilable/test12789.d(91): gd is default-initialized with NaN
compilable/test12789.d(92): gr is default-initialized with NaN
compilable/test12789.d(94): garrf is default-initialized with NaN
compilable/test12789.d(95): garrd is default-initialized with NaN
compilable/test12789.d(96): garrr is default-initialized with NaN
---
*/

float gf;
double gd;
real gr;

float[2] garrf;
double[2] garrd;
real[2] garrr;

float gfx = float.init;
double gdx = float.init;
real grx = float.init;

float gfn = float.nan;
double gdn = float.nan;
real grn = float.nan;

float[2] garrfn = float.nan;
double[2] garrdn = float.nan;
real[2] garrrn = float.nan;

void test(float x) { }

union U
{
    float x;
    int y;
}

struct SU
{
    union
    {
        float x;  // bug? emits diagnostic on -transition=nan
        int y;
    }
}

struct S
{
    float gf;
    double gd;
    real gr;

    float[2] garrf;
    double[2] garrd;
    real[2] garrr;

    float gfx = float.init;
    double gdx = float.init;
    real grx = float.init;

    float gfn = float.nan;
    double gdn = float.nan;
    real grn = float.nan;

    float[2] garrfn = float.nan;
    double[2] garrdn = float.nan;
    real[2] garrrn = float.nan;
}

void main()
{
    float gf;
    double gd;
    real gr;

    float[2] garrf;
    double[2] garrd;
    real[2] garrr;

    float gfx = float.init;
    double gdx = float.init;
    real grx = float.init;

    float gfn = float.nan;
    double gdn = float.nan;
    real grn = float.nan;

    float[2] garrfn = float.nan;
    double[2] garrdn = float.nan;
    real[2] garrrn = float.nan;
}
