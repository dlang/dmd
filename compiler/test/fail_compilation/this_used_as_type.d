/*
TEST_OUTPUT:
---
fail_compilation/this_used_as_type.d(15): Error: basic type expected, not `this`, did you mean `typeof(this)`?
fail_compilation/this_used_as_type.d(19): Error: basic type expected, not `super`, did you mean `typeof(super)`?
fail_compilation/this_used_as_type.d(27): Error: basic type expected, not `this`, did you mean `typeof(this)`?
fail_compilation/this_used_as_type.d(29): Error: basic type expected, not `this`, did you mean `typeof(this)`?
fail_compilation/this_used_as_type.d(30): Error: basic type expected, not `super`, did you mean `typeof(super)`?
fail_compilation/this_used_as_type.d(35): Error: basic type expected, not `this`, did you mean `typeof(this)`?
fail_compilation/this_used_as_type.d(41): Error: basic type expected, not `super`, did you mean `typeof(super)`?
---
*/

// Note: moved from `fail_typeof.d` as they're now parse errors
enum E1 : this
{
    fail,
}
enum E3 : super
{
    fail,
}

struct Test
{
    // postblit can't be template
    this()(this);

    void f()(this);
    void g()(super);

    void h()
    {
        // used to work in a method, but not in spec grammar
        alias this p;
    }
}

class C
{
    super* p;
}
