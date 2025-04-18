/*
REQUIRED_ARGS: -preview=tuples -vcolumns
TEST_OUTPUT:
---
fail_compilation/unpacking.d(29,14): Error: unpacked variable `b` needs a type or at least one storage class, did you mean `auto b`?
fail_compilation/unpacking.d(30,15): Error: unpacked variable `b` needs a type or at least one storage class, did you mean `auto b`?
fail_compilation/unpacking.d(30,18): Error: unpacked variable `c` needs a type or at least one storage class, did you mean `auto c`?
fail_compilation/unpacking.d(31,23): Error: unpacked variable `c` needs a type or at least one storage class, did you mean `auto c`?
fail_compilation/unpacking.d(33,16): Error: found `,` when expecting `=` following unpack declaration
fail_compilation/unpacking.d(34,10): Error: unexpected identifier `a` in declarator
fail_compilation/unpacking.d(34,17): Error: unexpected identifier `b` in declarator
fail_compilation/unpacking.d(36,17): Error: expected identifier after type `int` in unpack declaration
fail_compilation/unpacking.d(38,16): Error: `auto ref` unpacked variables are not supported
fail_compilation/unpacking.d(39,25): Error: unpacking `auto ref` parameters is not supported
fail_compilation/unpacking.d(40,21): Error: unpacking `lazy` parameters is not supported
fail_compilation/unpacking.d(40,34): Error: unpacking `out` parameters is not supported
---
*/

struct Tuple(T...)
{
    T expand;
    alias this = expand;
}
auto tuple(T...)(T args) => Tuple!T(args);

void main() // check parse errors
{
    (int a, b) = tuple(1, "2"); // error
    (int a, (b, c)) = tuple(1, tuple("2", 3.0)); // error
    (int a, (auto b, c)) = tuple(1, tuple("2", 3.0)); // error

    auto (a, b), c = t; // error
    (int a, int b), c = t; // error

    (char a, int) = t; // error

    (auto ref a,) = t; // error
    alias a = (auto ref (x,)) {}; // error
    alias a = (lazy (x,), y, out (z,)) {}; // error
}
