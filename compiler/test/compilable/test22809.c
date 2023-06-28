// https://issues.dlang.org/show_bug.cgi?id=22809

typedef unsigned long size_t;

// #define __builtin_offsetof(t,i) ((size_t)((char *)&((t *)0)->i - (char *)0))

struct Foo {
    int x, y;
};

//int y = __builtin_offsetof(struct Foo, y);
//_Static_assert(__builtin_offsetof(struct Foo, y)==4, "");

int y = ((size_t)((char *)&((struct Foo *)1)->x - (char *)1));
_Static_assert(((size_t)((char *)&((struct Foo *)0)->y - (char *)0))==4, "");


// https://issues.dlang.org/show_bug.cgi?id=23584

int foo(float bar)
{
    return __builtin_bit_cast(unsigned int, bar);
}

void test23584()
{
    int i = foo(3.5);
    _Static_assert(foo(3.5) == 0x40600000, "1");
}
