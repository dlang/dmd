class Foo
{
    final void fcall(T)(T t) { }
    static void scall(T)(T t) {}
}

interface Bar
{
    final void fcall(T)(T t) { }
    static void scall(T)(T t) {}
}

class Baz : Bar {}

void test()
{
    Foo foo; foo.fcall(2); foo.scall(2);
    Bar bar; bar.fcall(2); bar.scall(2);
    Baz baz; baz.fcall(2); baz.scall(2);
}
