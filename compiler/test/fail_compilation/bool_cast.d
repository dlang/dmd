/*
REQUIRED_ARGS: -de -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/bool_cast.d(15): Deprecation: cast from `ubyte[]` to `bool[]` not allowed in safe code
fail_compilation/bool_cast.d(15):        Source element may have bytes which are not 0 or 1
fail_compilation/bool_cast.d(19): Deprecation: cast from `int*` to `bool*` not allowed in safe code
fail_compilation/bool_cast.d(19):        Source element may have bytes which are not 0 or 1
---
*/

void main() @safe
{
    ubyte[] a = [2, 4];
    auto b = cast(bool[]) a; // reinterprets a's data
    auto c = cast(bool[]) [2, 4]; // literal cast applies to each element

    int i = 2;
    auto p = cast(bool*) &i;
}
