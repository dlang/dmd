/* TEST_OUTPUT:
---
fail_compilation/bitfields1.c(103): Error: no alignment-specifier for bit field declaration
fail_compilation/bitfields1.c(109): Error: empty struct-declaration-list for `struct T`
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

