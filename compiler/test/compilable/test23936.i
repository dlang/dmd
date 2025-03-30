// https://issues.dlang.org/show_bug.cgi?ide=23936

#pragma pack(push,16)
typedef struct AAATAG {
    int LastExceptionFromRip;
} AAA;
#pragma pack(pop)

#pragma pack(push, 16)
typedef struct {
    long long val;
} BBB;
#pragma pack(pop)


__pragma(pack(push,16))
typedef struct XXXTAG {
    int LastExceptionFromRip;
} XXX;
__pragma(pack(pop))

__pragma(pack(push, 16))
typedef struct {
    long long val;
} YYY;
__pragma(pack(pop))


_Static_assert(_Alignof(AAA) == 16, "1");
_Static_assert(_Alignof(BBB) == 16, "2");
_Static_assert(_Alignof(XXX) == 16, "3");
_Static_assert(_Alignof(YYY) == 16, "4");
