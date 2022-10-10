/* DISABLED: win32 win64
 */

// https://issues.dlang.org/show_bug.cgi?id=23346

struct S1 {
    unsigned d:31;
    int e:1;
};

struct S2 {
    unsigned d:31;
    _Bool e:1;
};

struct S3 {
    unsigned d:31;
    char e:1;
};

_Static_assert(sizeof(struct S1) == 4, "size != 4");
_Static_assert(sizeof(struct S2) == 4, "size != 4"); // 8 on Windows
_Static_assert(sizeof(struct S3) == 4, "size != 4"); // 8 on Windows
