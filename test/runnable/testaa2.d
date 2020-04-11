/*
PERMUTE_ARGS:
RUN_OUTPUT:
---
foo()
foo() 2
foo() 3
foo() 4
c["foo"] = 3
c["bar"] = 4
Success
---
*/

extern(C) int printf(const char*, ...);

/************************************************/

int[string] a;

size_t foo(immutable char [3] s)
{
    printf("foo()\n");
    int[string] b;
    string[] key;
    int[] value;
    printf("foo() 2\n");
    key = a.keys;
    printf("foo() 3\n");
    value = a.values;
    printf("foo() 4\n");
    return a.length + b.length;
}

void foo2()
{
    int[string] c;
    string[] key;
    int[] value;
    int i;

    assert(c.length == 0);
    key = c.keys;
    assert(key.length == 0);
    value = c.values;
    assert(value.length == 0);

    c["foo"] = 3;
    assert(c["foo"] == 3);
    assert(c.length == 1);
    key = c.keys;
    assert(key.length == 1);
    value = c.values;
    assert(value.length == 1);
    assert(value[0] == 3);

    c["bar"] = 4;
    assert(c["bar"] == 4);
    assert(c.length == 2);
    key = c.keys;
    assert(key.length == 2);
    value = c.values;
    assert(value.length == 2);

    for (i = 0; i < key.length; i++)
    {
        printf("c[\"%.*s\"] = %d\n", cast(int)key[i].length, key[i].ptr, value[i]);
    }

    assert("foo" in c);
    c.remove("foo");
    assert(!("foo" in c));
    assert(c.length == 1);

    assert("bar" in c);
    c.remove("bar");
    assert(!("bar" in c));
    assert(c.length == 0);
}

void testaa()
{
    size_t i = foo("abc");
    assert(i == 0);

    foo2();
}

/************************************************/

void test1899()
{
    int[3][string] AA;
    int[3] x = [5,4,3];
    AA["abc"] = x;
    assert(AA["abc"] == x);
    AA["def"] = [1,2,3];
    assert(AA["def"]==[1,2,3]);
}

/************************************************/

void foo4523()
{
   int[string] aa = ["test":0, "test2":1];

   bool found = aa.remove("test");
   assert(found);
   bool notfound = aa.remove("nothing");
   assert(!notfound);
}

void test4523()
{
    foo4523();
    static assert({ foo4523(); return true; }());
}

void test3825x()
{
    return; // depends on AA implementation
    static int ctor, cpctor, dtor;

    static struct S
    {
        this(int)  { ++ctor; }
        this(this) { ++cpctor; }
        ~this()    { ++dtor; }
    }

    int[S] aa;
    {
        auto value = S(1);
        assert(ctor==1 && cpctor==0 && dtor==0);

        ref getRef(ref S s = value) { return s; }
        auto getVal() { return value; }

        aa[value] = 10;
        assert(ctor==1 && cpctor==1 && dtor==0);

        aa[getRef()] += 1;
        assert(ctor==1 && cpctor==1 && dtor==0);

        aa[getVal()] += 1;
        assert(ctor==1 && cpctor==2 && dtor==1);
    }
    assert(ctor==1 && cpctor==2 && dtor==2);
    assert(ctor + cpctor - aa.length == dtor);
}

/************************************************/
// https://issues.dlang.org/show_bug.cgi?id=10106

struct GcPolicy10106 {}

struct Uint24Array10106(SP = GcPolicy10106)
{
    this(this) {}
}

struct InversionList10106(SP = GcPolicy10106)
{
    Uint24Array10106!SP data;
}

alias InversionList10106!GcPolicy10106 CodepointSet10106;

struct PropertyTable10106
{
    CodepointSet10106[string] table;
}

/************************************************/

int main()
{
    testaa();
    test1899();
    test4523();
    test3825x();

    printf("Success\n");
    return 0;
}
