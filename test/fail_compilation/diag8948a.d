/*
TEST_OUTPUT:
---
fail_compilation/diag8948a.d(5): Error: cannot implicitly convert expression (a) of type:
  void function(int, float)
to:
  void function(float, int)
---
*/

#line 1
void main()
{
    void function(int, float) a;
    void function(float, int) b;
    b = a;    
}
