/*
TEST_OUTPUT:
---
fail_compilation/fail331.d(12): Error: cannot use `typeof(return)` inside function `foo` with inferred return type
    typeof(return) result;
                   ^
---
*/

auto foo()
{
    typeof(return) result;
    return result;
}
