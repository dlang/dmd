/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test16589.d(46): Error: returning `&this.data` escapes a reference to parameter `this`
        return &data;
               ^
fail_compilation/test16589.d(44):        perhaps annotate the function with `return`
    @safe int* access1()
               ^
fail_compilation/test16589.d(51): Error: returning `&this` escapes a reference to parameter `this`
        return &this;
               ^
fail_compilation/test16589.d(49):        perhaps annotate the function with `return`
    @safe S* access2()
             ^
fail_compilation/test16589.d(57): Error: returning `&s.data` escapes a reference to parameter `s`
    return &s.data;
           ^
fail_compilation/test16589.d(55):        perhaps annotate the parameter with `return`
@safe int* access3(ref S s)
                         ^
fail_compilation/test16589.d(62): Error: returning `&s` escapes a reference to parameter `s`
    return &s;
           ^
fail_compilation/test16589.d(60):        perhaps annotate the parameter with `return`
@safe S* access4(ref S s)
                       ^
fail_compilation/test16589.d(67): Error: returning `&s.data` escapes a reference to parameter `s`
    return &s.data;
           ^
fail_compilation/test16589.d(72): Error: returning `& s` escapes a reference to parameter `s`
    return &s;
           ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=16589

struct S
{
    int data;

    @safe int* access1()
    {
        return &data;
    }

    @safe S* access2()
    {
        return &this;
    }
}

@safe int* access3(ref S s)
{
    return &s.data;
}

@safe S* access4(ref S s)
{
    return &s;
}

@safe int* access5(S s)
{
    return &s.data;
}

@safe S* access6(S s)
{
    return &s;
}

class C
{
    int data;

    @safe int* access7()
    {
        return &data;
    }
}
