/*
TEST_OUTPUT:
---
fail_compilation/diag8948f.d(4): Error: cannot implicitly convert expression (__lambda1) of type:
  int function(int _param_0) pure nothrow @safe
to:
  int function()
fail_compilation/diag8948f.d(5): Error: cannot implicitly convert expression (__lambda2) of type:
  int function(int _param_0) pure nothrow @safe
to:
  int function()
---
*/

#line 1
void main()
{
    alias int function() Func;
    Func func1 = (int) { return 1; };
    Func func2 = (int a) => 1;
}
