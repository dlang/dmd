/*
REQUIRED_ARGS: -preview=tuples -vcolumns
TEST_OUTPUT:
---
fail_compilation/unpacking_extern.d(19,9): Error: variable `unpacking_extern.a` extern symbols cannot have initializers
fail_compilation/unpacking_extern.d(19,12): Error: variable `unpacking_extern.b` extern symbols cannot have initializers
fail_compilation/unpacking_extern.d(20,14): Error: variable `unpacking_extern.c` extern symbols cannot have initializers
fail_compilation/unpacking_extern.d(20,17): Error: variable `unpacking_extern.d` extern symbols cannot have initializers
---
*/

struct Tuple(T...)
{
    T expand;
    alias this = expand;
}
auto tuple(T...)(T args) => Tuple!T(args);

extern (a, b) = tuple(1,2); // error
auto extern (c, d) = tuple(1,2); // error
