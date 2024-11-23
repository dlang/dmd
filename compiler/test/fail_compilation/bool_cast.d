/*
REQUIRED_ARGS: -de -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/bool_cast.d(23): Deprecation: cast from `ubyte[]` to `bool[]` not allowed in safe code
    auto b = cast(bool[]) a; // reinterprets a's data
             ^
fail_compilation/bool_cast.d(23):        Source element may have bytes which are not 0 or 1
fail_compilation/bool_cast.d(28): Deprecation: cast from `int*` to `bool*` not allowed in safe code
    auto p = cast(bool*) &i;
             ^
fail_compilation/bool_cast.d(28):        Source element may have bytes which are not 0 or 1
fail_compilation/bool_cast.d(30): Deprecation: cast from `bool*` to `byte*` not allowed in safe code
    auto bp = cast(byte*) &v;
              ^
fail_compilation/bool_cast.d(30):        Target element could be assigned a byte which is not 0 or 1
---
*/

void main() @safe
{
    ubyte[] a = [2, 4];
    auto b = cast(bool[]) a; // reinterprets a's data
    auto c = cast(bool[]) [2, 4]; // OK, literal cast applies to each element
    auto d = cast(const(byte)[]) b; // OK, result's elements are const

    int i = 2;
    auto p = cast(bool*) &i;
    bool v;
    auto bp = cast(byte*) &v;
    *bp = 2; // v is now invalid
}
