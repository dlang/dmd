/*
TEST_OUTPUT:
---
fail_compilation/diag8948d.d(5): Error: cannot implicitly convert expression (g) of type:
  void delegate(int, float)
to:
  void delegate(float, int)
---
*/

#line 1
void main()
{
    void delegate(int, float) g;
    void delegate(float, int) h;
    h = g;
}
