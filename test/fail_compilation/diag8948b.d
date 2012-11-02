/*
TEST_OUTPUT:
---
fail_compilation/diag8948b.d(5): Error: cannot implicitly convert expression (c) of type:
  void delegate(int, float)
to:
  void function(float, int)
---
*/

#line 1
void main()
{
    void delegate(int, float) c;
    void function(float, int) d;
    d = c; 
}
