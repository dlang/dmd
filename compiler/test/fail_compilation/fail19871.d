/*
TEST_OUTPUT:
---
fail_compilation/fail19871.d(16): Error: `struct Struct` may not define both a rvalue constructor and a copy constructor
struct Struct
^
fail_compilation/fail19871.d(25):        rvalue constructor defined here
    this(Struct) {}
    ^
fail_compilation/fail19871.d(19):        copy constructor defined here
    this(ref Struct other)
    ^
---
*/

struct Struct
{
    @disable this();
    this(ref Struct other)
    {
        const Struct s = void;
        this(s);
    }

    this(Struct) {}
}
