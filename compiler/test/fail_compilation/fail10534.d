/*
TEST_OUTPUT:
---
fail_compilation/fail10534.d(60): Error: illegal operator `+` for `a` of type `int delegate()`
        auto c1 = a + b;  // passes (and will crash if c1() called)
                  ^
fail_compilation/fail10534.d(60): Error: illegal operator `+` for `b` of type `int delegate()`
        auto c1 = a + b;  // passes (and will crash if c1() called)
                      ^
fail_compilation/fail10534.d(61): Error: illegal operator `-` for `a` of type `int delegate()`
        auto c2 = a - b;  // passes (and will crash if c2() called)
                  ^
fail_compilation/fail10534.d(61): Error: illegal operator `-` for `b` of type `int delegate()`
        auto c2 = a - b;  // passes (and will crash if c2() called)
                      ^
fail_compilation/fail10534.d(62): Error: illegal operator `/` for `a` of type `int delegate()`
        auto c3 = a / b;  // a & b not of arithmetic type
                  ^
fail_compilation/fail10534.d(62): Error: illegal operator `/` for `b` of type `int delegate()`
        auto c3 = a / b;  // a & b not of arithmetic type
                      ^
fail_compilation/fail10534.d(63): Error: illegal operator `*` for `a` of type `int delegate()`
        auto c4 = a * b;  // a & b not of arithmetic type
                  ^
fail_compilation/fail10534.d(63): Error: illegal operator `*` for `b` of type `int delegate()`
        auto c4 = a * b;  // a & b not of arithmetic type
                      ^
fail_compilation/fail10534.d(68): Error: illegal operator `+` for `a` of type `int function()`
        auto c1 = a + b;
                  ^
fail_compilation/fail10534.d(68): Error: illegal operator `+` for `b` of type `int function()`
        auto c1 = a + b;
                      ^
fail_compilation/fail10534.d(69): Error: illegal operator `-` for `a` of type `int function()`
        auto c2 = a - b;
                  ^
fail_compilation/fail10534.d(69): Error: illegal operator `-` for `b` of type `int function()`
        auto c2 = a - b;
                      ^
fail_compilation/fail10534.d(70): Error: illegal operator `/` for `a` of type `int function()`
        auto c3 = a / b;
                  ^
fail_compilation/fail10534.d(70): Error: illegal operator `/` for `b` of type `int function()`
        auto c3 = a / b;
                      ^
fail_compilation/fail10534.d(71): Error: illegal operator `*` for `a` of type `int function()`
        auto c4 = a * b;
                  ^
fail_compilation/fail10534.d(71): Error: illegal operator `*` for `b` of type `int function()`
        auto c4 = a * b;
                      ^
---
*/

void main()
{
    {
        int delegate() a = ()=>5;
        int delegate() b = ()=>5;
        auto c1 = a + b;  // passes (and will crash if c1() called)
        auto c2 = a - b;  // passes (and will crash if c2() called)
        auto c3 = a / b;  // a & b not of arithmetic type
        auto c4 = a * b;  // a & b not of arithmetic type
    }
    {
        int function() a = ()=>5;
        int function() b = ()=>5;
        auto c1 = a + b;
        auto c2 = a - b;
        auto c3 = a / b;
        auto c4 = a * b;
    }
}
