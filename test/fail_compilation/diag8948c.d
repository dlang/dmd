/*
TEST_OUTPUT:
---
fail_compilation/diag8948c.d(5): Error: cannot implicitly convert expression (e) of type:
  void function(int, float)
to:
  void delegate(float, int)
---
*/

#line 1
void main()
{
    void function(int, float) e;
    void delegate(float, int) f;
    f = e;
}
