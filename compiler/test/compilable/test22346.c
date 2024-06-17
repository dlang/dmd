/* DISABLED: win32 win64 linux32 osx32 osx64 freebsd32 openbsd32
 */

// https://issues.dlang.org/show_bug.cgi?id=23346

#pragma pack(pop) // do nothing

struct NotPacked1 {
    int x;
    long y;
};

#pragma pack(push, 4)
struct Packed {
    int x;
    long y;
};
#pragma pack(pop)

struct NotPacked {
    int x;
    long y;
};

int x[3] = {
        sizeof(struct NotPacked1),
        sizeof(struct Packed),
        sizeof(struct NotPacked) };

_Static_assert(sizeof(struct NotPacked1) == 16, "1");
_Static_assert(sizeof(struct Packed)     == 12, "2");
_Static_assert(sizeof(struct NotPacked ) == 16, "3");
