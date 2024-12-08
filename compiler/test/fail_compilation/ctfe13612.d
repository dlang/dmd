/*
TEST_OUTPUT:
---
fail_compilation/ctfe13612.d(25): Error: function `ctfe13612.S.recurse` CTFE recursion limit exceeded
    int recurse()
        ^
fail_compilation/ctfe13612.d(30):        called from here: `s.recurse()`
        return s.recurse();
                        ^
fail_compilation/ctfe13612.d(25):        1000 recursive calls to function `recurse`
    int recurse()
        ^
fail_compilation/ctfe13612.d(33):        called from here: `(new S).recurse()`
static assert(new S().recurse());
                             ^
fail_compilation/ctfe13612.d(33):        while evaluating: `static assert((new S).recurse())`
static assert(new S().recurse());
^
---
*/

class S
{
    int x;
    int recurse()
    {
        S s;
        assert(!x); // Error: class 'this' is null and cannot be dereferenced
        s = new S();
        return s.recurse();
    }
}
static assert(new S().recurse());
