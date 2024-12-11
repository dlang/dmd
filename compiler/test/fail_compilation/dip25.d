/*
REQUIRED_ARGS:
TEST_OUTPUT:
---
fail_compilation/dip25.d(27): Error: returning `this.buffer[]` escapes a reference to parameter `this`
        return buffer[];
                     ^
fail_compilation/dip25.d(25):        perhaps annotate the function with `return`
    @property const(char)[] filename() const pure nothrow @safe
                            ^
fail_compilation/dip25.d(32): Error: returning `identity(x)` escapes a reference to parameter `x`
ref int fun(return int x) @safe { return identity(x); }
                                                 ^
fail_compilation/dip25.d(33): Error: returning `identity(x)` escapes a reference to parameter `x`
ref int fun2(ref int x) @safe { return identity(x); }
                                               ^
fail_compilation/dip25.d(33):        perhaps annotate the parameter with `return`
ref int fun2(ref int x) @safe { return identity(x); }
                     ^
---
*/
struct Data
{
    char[256] buffer;
    @property const(char)[] filename() const pure nothrow @safe
    {
        return buffer[];
    }
}

ref int identity(return ref int x) @safe { return x; }
ref int fun(return int x) @safe { return identity(x); }
ref int fun2(ref int x) @safe { return identity(x); }

void main()
{
    Data d;
    const f = d.filename;
}
