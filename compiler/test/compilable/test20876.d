// https://issues.dlang.org/show_bug.cgi?id=20876

struct Array
{
    void opSliceAssign(Foo) {}
    void opSliceAssign(Foo, size_t, size_t) {}
}

struct Foo {
    Bar _bar;
}

struct Bar {
  version (Bug)
    this(ref Bar) { }
  else
    this(Bar) { }
}

void main()
{
    Foo foo;
    Array arr;
    arr[] = foo;
}
