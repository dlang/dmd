// https://github.com/dlang/dmd/issues/21271
#define PUSH __pragma(pack(push))
#define PACK  __pragma(pack(1))
#define POP __pragma(pack(pop))

PUSH
PACK
struct S21271_1 {
    int x;
};
_Static_assert(_Alignof(struct S21271_1)==1, "1");
POP
struct S21271_2 {
    int x;
};
_Static_assert(_Alignof(struct S21271_2)==_Alignof(int), "2");
