struct S1 {unsigned char c;int i;};
#pragma pack(push, 2)
struct S2 {unsigned char c;int i;};
#pragma pack(push, 1)
struct S3 {unsigned char c;int i;};
#pragma pack(pop)
struct S4 {unsigned char c;int i;};
#pragma pack(pop)
struct S5 {unsigned char c;int i;};

_Static_assert(_Alignof(struct S1) == 4, "alignof S1");
_Static_assert(_Alignof(struct S2) == 2, "alignof S2");
_Static_assert(_Alignof(struct S3) == 1, "alignof S3");
_Static_assert(_Alignof(struct S4) == 2, "alignof S4");
_Static_assert(_Alignof(struct S5) == 4, "alignof S5");

_Static_assert(sizeof(struct S1) == 8, "sizeof S1");
_Static_assert(sizeof(struct S2) == 6, "sizeof S2");
_Static_assert(sizeof(struct S3) == 5, "sizeof S3");
_Static_assert(sizeof(struct S4) == 6, "sizeof S4");
_Static_assert(sizeof(struct S5) == 8, "sizeof S5");
