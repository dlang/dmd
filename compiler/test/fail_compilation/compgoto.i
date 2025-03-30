/* TEST_OUTPUT:
---
fail_compilation/compgoto.i(105): Error: unary `&&` computed goto extension is not supported
fail_compilation/compgoto.i(106): Error: `goto *` computed goto extension is not supported
---
 */

// https://gcc.gnu.org/onlinedocs/gcc/Labels-as-Values.html

#line 100

void test()
{
    void *ptr;
  foo:
    ptr = &&foo;
    goto *ptr;
}
