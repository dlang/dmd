/+
TEST_OUTPUT:
---
fail_compilation/structinit.d(21): Error: `z` is not a member of `Foo`
fail_compilation/structinit.d(23): Error: duplicate initializer for field `a`
fail_compilation/structinit.d(44): Error: constructor `structinit.FooDisabled.this` cannot be used because it is annotated with `@disable`
fail_compilation/structinit.d(45): Error: constructor `structinit.FooDisabled.this` cannot be used because it is annotated with `@disable`
fail_compilation/structinit.d(46): Error: constructor `structinit.FooDisabled.this` cannot be used because it is annotated with `@disable`
---
+/

struct Foo
{
    int a;
    bool b;
    float c;
}

void test1()
{
    bar(Foo({z: 1}));
    bar(Foo({a: "error"})); // TODO
    bar(Foo({a: 1, a:1}));
    bar(Foo({a:1, 1}));
    bar(Foo({c: 0.1, b: true, a: 2}));
}

void test1a()
{
    enum f = Foo({a: 1, b: true, c: 0.5});
    static assert(f.a == 1);
    static assert(f.b == true);
    static assert(f.c == 0.5);
}

struct FooDisabled
{
    @disable this();
    int a;
}

void test2()
{
    bar(FooDisabled({a: 1}));
    bar(FooDisabled({a: true}));
    bar(FooDisabled({b: 1}));
}

struct FooDefault
{
    this(int a);
    int a;
}

// TODO
//void test3()
//{
    //bar(FooDefault({a: 1}));
    //bar(FooDefault({a: true}));
    //bar(FooDefault({b: 1}));
//}

void bar(Foo foo);

//void totallyInvalid()
//{
    ////bar(Foo({1}));
    ////bar(Foo({1));
//}
