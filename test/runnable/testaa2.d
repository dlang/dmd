// PERMUTE_ARGS:

extern(C) int printf(const char*, ...);

int main()
{
    testaa();
    bug1899();
    printf("Success\n");
    return 0;
}

void testaa()
{
    size_t i = foo("abc");
    printf("i = %d\n", i);
    assert(i == 0);

    foo2();
}

int a[string];

size_t foo(invariant char [3] s)
{
    printf("foo()\n");
    int b[string];
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
    int c[string];
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
	printf("c[\"%.*s\"] = %d\n", key[i], value[i]);
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

void bug1899() 
{
    int[3][string] AA;
    int[3] x = [5,4,3];
    AA["abc"] = x;
    assert(AA["abc"] == x);
    AA["def"] = [1,2,3];
    assert(AA["def"]==[1,2,3]);
}
