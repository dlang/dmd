/* TEST_OUTPUT:
---
fail_compilation/enumtype.c(111): Error: enum member `enumtype.E2.A2` enum member value `549755813889L` does not fit in `int`
---
 */

#line 100

enum E1 { A1 = 0, B1 = sizeof(A1), C1 = 1LL, D1 = sizeof(C1), F1 = -1U, G1 };

_Static_assert(A1 == 0, "in");
_Static_assert(B1 == 4, "in");
_Static_assert(C1 == 1, "in");
_Static_assert(D1 == 8, "in");
_Static_assert(F1 == -1U, "in");
_Static_assert(G1 == 0x100000000, "in");
_Static_assert(sizeof(enum E1) == 8, "in");

enum E2 : int { A2 = 0x8000000001LL };
