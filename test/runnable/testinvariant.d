// PERMUTE_ARGS:

extern(C) int printf(const char*, ...);

class Foo : Object
{
    void test() { }

    invariant()
    {
	printf("in invariant %p\n", this);
    }
}

int main()
{
    printf("hello\n");
    Foo f = new Foo();
    printf("f = %p\n", f);
    printf("f.sizeof = x%x\n", Foo.sizeof);
    printf("f.classinfo = %p\n", f.classinfo);
    printf("f.classinfo._invariant = %p\n", f.classinfo.base);
    f.test();
    printf("world\n");
    return 0;
}
