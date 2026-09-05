/*
TEST_OUTPUT:
---
fail_compilation/this_used_as_type.d(14): Error: basic type expected, not `this`, did you mean `typeof(this)`?
fail_compilation/this_used_as_type.d(18): Error: basic type expected, not `super`, did you mean `typeof(super)`?
fail_compilation/this_used_as_type.d(26): Error: basic type expected, not `this`, did you mean `typeof(this)`?
fail_compilation/this_used_as_type.d(28): Error: basic type expected, not `this`, did you mean `typeof(this)`?
fail_compilation/this_used_as_type.d(29): Error: basic type expected, not `super`, did you mean `typeof(super)`?
fail_compilation/this_used_as_type.d(34): Error: basic type expected, not `super`, did you mean `typeof(super)`?
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
}

class C
{
    super* p;
}
