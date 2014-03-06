struct Tuple(T) {
    T arg;
}

struct Foo1
{
    Bar1 b;
}
struct Bar1
{
    int x;
    Tuple!(Foo1) spam() { return Tuple!(Foo1)(); }
}

struct Foo2
{
    Bar2 b;
}
struct Bar2
{
    int x;
    Tuple!(Foo2[1]) spam() { return Tuple!(Foo2[1])(); }
}

void main() {}
