// REQUIRED_ARGS: -w

/*
TEST_OUTPUT:
---
fail_compilation/warn17933.d(14): Warning: float = double is performing truncating conversion
fail_compilation/warn17933.d(15): Warning: float += double is performing truncating conversion
fail_compilation/warn17933.d(22): Warning: return double from float function is performing truncating conversion
---
*/

void test17933()
{
    float f;
    double d;
    f = d;
    f += 0.1;
}

float testReturn(float f)
{
    return f * 0.5;
}

