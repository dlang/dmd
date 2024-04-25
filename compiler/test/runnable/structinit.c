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
    struct S3 tn = (struct S3) {{1}, 4};
    assert(tn.context[0] == 1);
    assert(tn.context[1] == 0);
    assert(tn.context[2] == 0);
    assert(tn.context[3] == 0);
    assert(tn.id == 4);
}

/**************************************/
// https://issues.dlang.org/show_bug.cgi?id=24274

struct S0
{
    struct
    {
        char short_data[24];
    };
    int length;
};

void test4()
{
    struct S0 s0 = { {.short_data = {1}}, .length = 2};
    assert(s0.short_data[0] == 1);
    assert(s0.length == 2);
}

/**************************************/

struct S1
{
    struct
    {
        int long_data;
        char short_data[24];
    };
    int length;
};

void test5()
{
    struct S1 s1 = { {.short_data = {7}}, .length = 8};
    assert(s1.long_data == 0);
    assert(s1.short_data[0] == 7);
    assert(s1.length == 8);
}

/**************************************/

struct S6
{
    int abc[4];
};

void test6()
{
    struct S6 s = {{4},5,6,7};
    assert(s.abc[0] == 4);
    assert(s.abc[1] == 0);
    assert(s.abc[2] == 0);
    assert(s.abc[3] == 0);

    struct S6 t = {4,{5},6,7};
    assert(t.abc[0] == 4);
    assert(t.abc[1] == 5);
    assert(t.abc[2] == 6);
    assert(t.abc[3] == 7);
}

/**************************************/
// https://issues.dlang.org/show_bug.cgi?id=24495
struct Subitem {
    int x;
    int y;
};

struct Item {

    int a;

    struct {
        int b1;
        struct Subitem b2;
        int b3;
    };

};

void test7() {

    struct Item first = {
        .a = 1,
        .b1 = 2,
        .b3 = 3,
    };
    struct Item second = {
        .a = 1,
        {
            .b1 = 2,
            .b2 = { 1, 2 },
            .b3 = 3
        }
    };

    assert(second.a == 1);
    assert(second.b1 == 2);
    assert(second.b2.x == 1);
    assert(second.b2.y == 2);
    assert(second.b3 == 3);
}


/**************************************/
// https://issues.dlang.org/show_bug.cgi?id=24277
struct S8
{
    int s;
    struct
    {
        int vis;
        int count;
        int id;
        struct
        {
            int symbol;
            int state;
        } leaf;
    };
};

struct S8 s8 = (struct S8) {
    .s = 10,
    {
        .count = 20,
        .id = 30,
        .leaf = {.symbol = 40, .state = 50},
    }
};

void test8()
{
    assert(s8.id == 30);
    assert(s8.leaf.symbol == 40);
    assert(s8.leaf.state == 50);
}

/**************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    return 0;
}
