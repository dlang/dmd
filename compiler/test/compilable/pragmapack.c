/* REQUIRED_ARGS: -wi
TEST_OUTPUT:
---
compilable/pragmapack.c(101): Warning: current pack attribute is default
compilable/pragmapack.c(104): Warning: current pack attribute is 2
compilable/pragmapack.c(112): Warning: current pack attribute is default
compilable/pragmapack.c(117): Warning: current pack attribute is 8
compilable/pragmapack.c(123): Warning: current pack attribute is default
compilable/pragmapack.c(128): Warning: current pack attribute is 8
compilable/pragmapack.c(135): Warning: current pack attribute is default
compilable/pragmapack.c(140): Warning: current pack attribute is default
compilable/pragmapack.c(143): Warning: current pack attribute is 2
compilable/pragmapack.c(145): Warning: current pack attribute is 2
compilable/pragmapack.c(147): Warning: current pack attribute is 2
compilable/pragmapack.c(149): Warning: current pack attribute is 2
compilable/pragmapack.c(151): Warning: current pack attribute is 2
compilable/pragmapack.c(153): Warning: current pack attribute is 2
compilable/pragmapack.c(155): Warning: current pack attribute is 2
compilable/pragmapack.c(157): Warning: current pack attribute is 8
compilable/pragmapack.c(159): Warning: current pack attribute is 2
compilable/pragmapack.c(161): Warning: current pack attribute is 2
compilable/pragmapack.c(163): Warning: current pack attribute is default
---
*/

// Test #pragma pack

#line 100

#pragma pack(show)

#pragma pack(2)
#pragma pack(show)
struct S
{
    int i;
    short j;
    double k;
};
#pragma pack()
#pragma pack(show)

_Static_assert(sizeof(struct S) == 4 + 2 + 8, "1");

#pragma pack(push, 8)
#pragma pack(show)
struct S2
{
    char a, b;
};
#pragma pack(pop)
#pragma pack(show)

_Static_assert(sizeof(struct S2) == 8, "2");

#pragma pack(push, 8)
#pragma pack(show)
struct S3
{
    unsigned short u;
    char a;
};
#pragma pack(pop)
#pragma pack(show)

_Static_assert(sizeof(struct S3) == 8, "3");

#pragma pack()
#pragma pack(show)
#pragma pack(2)
#pragma pack(push)
#pragma pack(show)
#pragma pack(push,2)
#pragma pack(show)
#pragma pack(push,abc)
#pragma pack(show)
#pragma pack(push,abc,2)
#pragma pack(show)
#pragma pack(pop)
#pragma pack(show)
#pragma pack(pop,a)
#pragma pack(show)
#pragma pack(pop,2)
#pragma pack(show)
#pragma pack(pop,a,b,4,8,c)
#pragma pack(show)
#pragma pack(pop);
#pragma pack(show)
#pragma pack(pop);
#pragma pack(show)
#pragma pack(pop);
#pragma pack(show)

int x;
