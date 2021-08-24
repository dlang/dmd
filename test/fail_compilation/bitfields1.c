/* TEST_OUTPUT:
---
fail_compilation/bitfields1.c(103): Error: no alignment-specifier for bit field declaration
fail_compilation/bitfields1.c(108): Error: specifier-qualifier-list required
fail_compilation/bitfields1.c(111): Error: specifier-qualifier-list required
fail_compilation/bitfields1.c(112): Error: specifier-qualifier-list required
---
 */

#line 100

struct S
{
    _Alignas(4) int a:3;
};

struct T
{
    :3;
};

struct E1 { :0; int x; };
struct E2 { int x; :0; };

