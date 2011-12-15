
extern(C) int printf(const char* fmt, ...);

/***************************************/

void test1()
{
    char[] a;

    int foo()
    {
        printf("foo\n");
        a ~= "foo";
        return 10;
    }

    foreach (i; 0 .. foo())
    {
        printf("%d\n", i);
        a ~= cast(char)('0' + i);
    }
    assert(a == "foo0123456789");

    foreach_reverse (i; 0 .. foo())
    {
        printf("%d\n", i);
        a ~= cast(char)('0' + i);
    }
    assert(a == "foo0123456789foo9876543210");
}

/***************************************/
// 7004

void func7004(A...)(A args)
{
    foreach (i, e; args){}        // OK
    foreach (uint i, e; args){}   // OK
    foreach (size_t i, e; args){} // NG
}
void test7004()
{
    func7004(1, 3.14);
}

/***************************************/
// 3187
class Collection
{
    int opApply(int delegate(ref Object) a)
    {
        return 0;
    }
}

Object testForeach(Collection level1, Collection level2)
{
    foreach (first; level1) {
        foreach (second; level2)
            return second;
    }
    return null;
}

void test3187()
{
    testForeach(new Collection, new Collection);
}

/***************************************/

int main()
{
    test1();
    test7004();
    test3187();

    printf("Success\n");
    return 0;
}
