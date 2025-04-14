/*
REQUIRED_ARGS: -preview=tuples -vcolumns
TEST_OUTPUT:
---
fail_compilation/unpacking.d(16,14): Error: unpacked variable `b` needs a type or at least one storage class, did you mean `auto b`?
fail_compilation/unpacking.d(17,15): Error: unpacked variable `b` needs a type or at least one storage class, did you mean `auto b`?
fail_compilation/unpacking.d(17,18): Error: unpacked variable `c` needs a type or at least one storage class, did you mean `auto c`?
fail_compilation/unpacking.d(18,23): Error: unpacked variable `c` needs a type or at least one storage class, did you mean `auto c`?
---
*/

import std.typecons : tuple;

void main()
{
    (int a, b) = tuple(1, "2"); // error
    (int a, (b, c)) = tuple(1, tuple("2", 3.0)); // error
    (int a, (auto b, c)) = tuple(1, tuple("2", 3.0)); // error
}
