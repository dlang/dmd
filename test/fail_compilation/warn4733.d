/*
REQUIRED_ARGS: -w
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/warn4733.d(20): Warning: implicit conversion of dynamic arrays to bool can be ambiguous and will be deprecated. Use one of: arr !is null, arr.length, or arr.ptr instead
fail_compilation/warn4733.d(21): Warning: implicit conversion of dynamic arrays to bool can be ambiguous and will be deprecated. Use one of: arr !is null, arr.length, or arr.ptr instead
fail_compilation/warn4733.d(22): Warning: implicit conversion of dynamic arrays to bool can be ambiguous and will be deprecated. Use one of: arr !is null, arr.length, or arr.ptr instead
fail_compilation/warn4733.d(23): Warning: implicit conversion of dynamic arrays to bool can be ambiguous and will be deprecated. Use one of: arr !is null, arr.length, or arr.ptr instead
fail_compilation/warn4733.d(24): Warning: implicit conversion of dynamic arrays to bool can be ambiguous and will be deprecated. Use one of: arr !is null, arr.length, or arr.ptr instead
fail_compilation/warn4733.d(25): Warning: implicit conversion of dynamic arrays to bool can be ambiguous and will be deprecated. Use one of: arr !is null, arr.length, or arr.ptr instead
fail_compilation/warn4733.d(26): Warning: implicit conversion of dynamic arrays to bool can be ambiguous and will be deprecated. Use one of: arr !is null, arr.length, or arr.ptr instead
fail_compilation/warn4733.d(27): Warning: implicit conversion of dynamic arrays to bool can be ambiguous and will be deprecated. Use one of: arr !is null, arr.length, or arr.ptr instead
---
*/

void main()
{
    int[] arr;
    assert(arr);
    assert(!arr);
    assert(arr || 0);
    assert(arr && 1);
    assert(arr ? true : false);
    do {} while(arr);
    for (; arr;) {}
    if (arr) {}
}
