void main()
{
    struct Foo {int i;}
    // allow because const, although param (member of literal, not of instance)
    // is not modifiable
    void test1(ref const(int)){}
    void test2(const ref int){}
    void test3(const ref const(int)){}
    enum Foo f = {i : 42};
    test1(f.i);
    test2(f.i);
    test3(f.i);
}
