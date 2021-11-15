// https://issues.dlang.org/show_bug.cgi?id=22362

typedef struct Foo {
    int x, y;
} Foo;

Foo gfoo = (Foo){0, 1};
int main(int argc, char** argv)
{
    Foo foo1 = (Foo){0};
    Foo foo2 = (Foo){0, 1};
}
