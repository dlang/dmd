/*
TEST_OUTPUT:
---
fail_compilation/fail152.d(15): Error: cannot use type `double` as an operand
---
*/

// 1028 Segfault using tuple inside asm code.

void a(X...)(X expr)
{
    alias X[0] var1;
    asm {
      //fld double ptr X[0];   // (1) segfaults
        fstp double ptr var1;  // (2) ICE
    }
}

void main()
{
   a(3.6);
}

