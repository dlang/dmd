module stacktrace2;

extern(C++) class Foo
{
    void bar()
    {
        throw new Exception("Hello");
    }
}
