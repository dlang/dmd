/* TEST_OUTPUT:
---
fail_compilation/enumtype2.c(101): Error: circular reference to enum base type `int`
---
 */

#line 100

enum E3 { A3 = sizeof(enum E3) };
