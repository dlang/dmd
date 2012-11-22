/*
TEST_OUTPUT:
---
fail_compilation/diag8948e.d(5): Error: cannot implicitly convert expression (i) of type:
  extern (C++) void function(int, float, string)
to:
  extern (C) void function(int, float, string)
---
*/

#line 1
void main()
{
    extern(C++) void function(int, float, string) i;
    extern(C) void function(int, float, string) j;
    j = i;
}
