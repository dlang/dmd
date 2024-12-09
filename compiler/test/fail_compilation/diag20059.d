/*
TEST_OUTPUT:
---
fail_compilation/diag20059.d(19): Error: expected return type of `string`, not `string[]`:
        return [ret];
        ^
fail_compilation/diag20059.d(17):        Return type of `string` inferred here.
        return ret;
        ^
---
*/

auto fail()
{
    string ret;
    if (true)
        return ret;
    else
        return [ret];
}
