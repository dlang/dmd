/*
REQUIRED_ARGS: -de -m64
TEST_OUTPUT:
---
fail_compilation/foreach_index_overflow.d(27): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach (int index, element; arr[0 .. 0x8000_0001]) {} // error
    ^
fail_compilation/foreach_index_overflow.d(29): Deprecation: foreach: loop index implicitly converted from `size_t` to `ushort`
    foreach (ushort index, element; arr[0 .. 0x1_0001]) {} // error
    ^
fail_compilation/foreach_index_overflow.d(32): Deprecation: foreach: loop index implicitly converted from `size_t` to `ubyte`
    foreach (ubyte i, x; data[]) {} // error
    ^
fail_compilation/foreach_index_overflow.d(34): Deprecation: foreach: loop index implicitly converted from `size_t` to `byte`
    foreach (byte i, x; data[0..0x81]) {} // error
    ^
---
*/

void main()
{
    enum { red, green, blue }
    foreach (int i, color; [red, green, blue]) {} // OK

    int[] arr;
    foreach (int index, element; arr[0 .. 0x8000_0000]) {} // OK
    foreach (int index, element; arr[0 .. 0x8000_0001]) {} // error
    foreach (ushort index, element; arr[0 .. 0x1_0000]) {} // OK
    foreach (ushort index, element; arr[0 .. 0x1_0001]) {} // error

    int[257] data;
    foreach (ubyte i, x; data[]) {} // error
    foreach (ubyte i, x; data[0..256]) {} // OK
    foreach (byte i, x; data[0..0x81]) {} // error
    foreach (byte i, x; data[0..0x80]) {} // OK
}
