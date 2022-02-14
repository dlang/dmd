// https://issues.dlang.org/show_bug.cgi?id=22698

struct S
{
    struct T { int x; };
};

struct T t;

/*******/

struct Bar {
    struct Foo {
        int x;
    } f;
};

struct Foo f = {3};

/*******/

struct Amy { int x; } *p;

struct Amy b;

