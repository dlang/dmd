// https://issues.dlang.org/show_bug.cgi?id=24031

#include <assert.h>

/**************************************/

struct ES {
    struct {
        char data[24];
    };
    int length;
};

struct ES empty = {.data = {1}, .length = 2};

void test1()
{
    assert(empty.data[0] == 1);
    assert(empty.length == 2);
}

/**************************************/

struct SH {
    int k;
    struct {
        struct {
            struct {
                int s;
            } f;
        };
    };
};

struct SH data = (struct SH) {
    .k = 1,
    {{.f = {.s = 2}}}
};

void test2()
{
    assert(data.k == 1);
    assert(data.f.s == 2);
}

/**************************************/

// https://issues.dlang.org/show_bug.cgi?id=24266

struct S3
{
    int context[4];
    int id;
};

void test3()
{
    struct S3 tn = (struct S3) {{0}, 4};
    assert(tn.id == 4);
}

/**************************************/

int main()
{
    test1();
    test2();
    test3();
    return 0;
}
