/*
REQUIRED_ARGS: -preview=tuples -vcolumns
TEST_OUTPUT:
---
fail_compilation/unpacking.d(19,14): Error: unpacked variable `b` needs a type or at least one storage class, did you mean `auto b`?
fail_compilation/unpacking.d(20,15): Error: unpacked variable `b` needs a type or at least one storage class, did you mean `auto b`?
fail_compilation/unpacking.d(20,18): Error: unpacked variable `c` needs a type or at least one storage class, did you mean `auto c`?
fail_compilation/unpacking.d(21,23): Error: unpacked variable `c` needs a type or at least one storage class, did you mean `auto c`?
fail_compilation/unpacking.d(23,16): Error: found `,` when expecting `=` following unpack declaration
fail_compilation/unpacking.d(24,10): Error: unexpected identifier `a` in declarator
fail_compilation/unpacking.d(24,17): Error: unexpected identifier `b` in declarator
---
*/

import std.typecons : tuple;

void main()
{
    (int a, b) = tuple(1, "2"); // error
    (int a, (b, c)) = tuple(1, tuple("2", 3.0)); // error
    (int a, (auto b, c)) = tuple(1, tuple("2", 3.0)); // error

    auto (a, b), c = t; // error
    (int a, int b), c = t; // error
}
