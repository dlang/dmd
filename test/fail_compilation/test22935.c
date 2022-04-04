/* TEST_OUTPUT:
---
fail_compilation/test22935.c(18): Error: array index 5 is out of bounds `[0..4]`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22935

typedef unsigned long size_t;
struct S { char a; char text[4]; };
//int tmp = __builtin_offsetof(struct S, text[0]);
int tmp = ((unsigned long)((char *)&((struct S *)0)->text[0] - (char *)0));

_Static_assert((unsigned long)((char *)&((struct S *)0)->text[0] - (char *)0) == 1, "1");
_Static_assert((unsigned long)((char *)&((struct S *)0)->text[2] - (char *)0) == 3, "2");
_Static_assert((unsigned long)((char *)&((struct S *)4)->text[2] - (char *)0) == 7, "3");

int tmp2 = ((unsigned long)((char *)&((struct S *)0)->text[5] - (char *)0));
