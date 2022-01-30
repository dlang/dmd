// https://issues.dlang.org/show_bug.cgi?id=22698

struct S
{
    struct T { int x; };
};

struct T t;

