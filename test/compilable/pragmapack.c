// Test #pragma pack

#pragma pack(2)
struct S
{
    int i;
    short j;
    double k;
};
#pragma pack()

_Static_assert(sizeof(struct S) == 4 + 2 + 8, "1");

#pragma pack(push, 8)
struct S2
{
    char a, b;
};
#pragma pack(pop)

_Static_assert(sizeof(struct S2) == 1 + 1, "2");

#pragma pack(push, 8)
struct S3
{
    unsigned short u;
    char a;
};
#pragma pack(pop)

_Static_assert(sizeof(struct S3) == 4, "3");

#pragma pack()
#pragma pack(show)
#pragma pack(2)
#pragma pack(push)
#pragma pack(push,2)
#pragma pack(push,abc)
#pragma pack(push,abc,2)
#pragma pack(pop)
#pragma pack(pop,a)
#pragma pack(pop,2)
#pragma pack(pop,a,b,4,8,c)

int x;
