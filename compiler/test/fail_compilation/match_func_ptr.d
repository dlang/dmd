/*
TEST_OUTPUT:
---
fail_compilation/match_func_ptr.d(21): Error: cannot match delegate literal to function pointer type `void function()`
    void function() f = delegate {};
                        ^
fail_compilation/match_func_ptr.d(22): Error: cannot match function literal to delegate type `void delegate()`
    void delegate() d = function {};
                        ^
fail_compilation/match_func_ptr.d(23): Error: cannot infer parameter types from `int function()`
    int function() f2 = i => 2;
                        ^
fail_compilation/match_func_ptr.d(24): Error: cannot infer parameter types from `int delegate(int, int)`
    int delegate(int, int) d2 = i => 2;
                                ^
---
*/

void main()
{
    void function() f = delegate {};
    void delegate() d = function {};
    int function() f2 = i => 2;
    int delegate(int, int) d2 = i => 2;
}
