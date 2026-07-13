// fix ImportC function redeclarations should be allowed in function scope

void test()
{

    struct Foo;
    struct Foo;
    struct Foo;
    enum bar;
    enum bar;
    enum bar;
    union see;
    union see;
    union see;
    int f();
    extern int f();
    int f();

    extern int h;
    extern int h;
}

void test1()
{
    extern int f();
    int f();

    extern int x;
    extern int x;
}
