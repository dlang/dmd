// REQUIRED_ARGS: -define:traits_getCmdlineConstant.test1=some_text=test -define:traits_getCmdlineConstant.test2=123 -define:traits_getCmdlineConstant.test3=123.456 "-define:traits_getCmdlineConstant.test4=Foo(4)" "-define:traits_getCmdlineConstant.test5=\"test\""

// Test for traits getCmdlineConstant

static assert(__traits(getCmdlineConstant, "test1") == "some_text=test");
static assert(__traits(getCmdlineConstant, "traits_getCmdlineConstant.test1") == "some_text=test");

enum TEST = __traits(getCmdlineConstant, "test1");
static assert(TEST == "some_text=test");

immutable int __test2_1 = __traits(getCmdlineConstant, "test2", int);
immutable long __test2_2 = __traits(getCmdlineConstant, "test2", long);
static assert(__test2_1 == 123);
static assert(__test2_2 == 123);

immutable float __test3_1 = __traits(getCmdlineConstant, "test3", float);
immutable double __test3_2 = __traits(getCmdlineConstant, "test3", double);
static assert(__test3_1 == 123.456);
static assert(__test3_2 == 123.456);

struct Foo {
    int a;
}

immutable Foo foo = __traits(getCmdlineConstant, "test4", Foo);
static assert(foo.a == 4);

static assert(__traits(getCmdlineConstant, "test5") == "\"test\"");
static assert(__traits(getCmdlineConstant, "test5", string) == "test");

static assert(__traits(getCmdlineConstant, "__no_def", false, "default") == "default");
static assert(__traits(getCmdlineConstant, "test1", false, "default") == "some_text=test");

static assert(__traits(getCmdlineConstant, "__no_def", int, 34) == 34);
static assert(__traits(getCmdlineConstant, "test2", int, 34) == 123);

static assert(__traits(getCmdlineConstant, "__no_def", double, 3.4) == 3.4);
static assert(__traits(getCmdlineConstant, "test3", double, 3.4) == 123.456);

static assert(__traits(getCmdlineConstant, "__no_def", Foo, Foo(31)).a == 31);
static assert(__traits(getCmdlineConstant, "test4", Foo(31)).a == 4);

static assert(__traits(getCmdlineConstant, "__no_def", false, "default") == "default");
static assert(__traits(getCmdlineConstant, "test5", false, "default") == "\"test\"");
static assert(__traits(getCmdlineConstant, "__no_def", string, "default") == "default");
static assert(__traits(getCmdlineConstant, "test5", string, "default") == "test");
