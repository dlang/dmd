/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/bool_cast.d(13): Deprecation: cast from `ubyte[]` to `bool[]` not allowed in safe code
fail_compilation/bool_cast.d(13):        Array data may have bytes which are not 0 or 1
---
*/

void main() @safe
{
    ubyte[] a = [2, 4];
    auto b = cast(bool[]) a; // reinterprets a's data
    auto c = cast(bool[]) [2, 4]; // literal cast applies to each element
}
