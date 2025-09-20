// https://github.com/dlang/dmd/issues/20157
// testing C intializers using designators

#include <assert.h>

struct top
{
    int a;
    int b;
};

union t_union
{
    int f;
    int g;
};

struct Foo
{
    int x;
    int y;
    struct top f;
};

struct Bar
{
    struct Foo b;
    int arr[3];
    union t_union u;
};

struct Bar test = {
    .b.x = 5,
    .b.y = 7,
    .b.f = {8, 9},
    .arr[0] = 10,
    .arr[1] = 11,
    .u.f = 13
};

int main()
{
    assert(test.b.x == 5);
    assert(test.b.y == 7);
    assert(test.b.f.a == 8);
    assert(test.b.f.b == 9);
    assert(test.arr[0] == 10);
    assert(test.arr[1] == 11);
    assert(test.u.f == 13);
    assert(test.u.g == 13);
}
