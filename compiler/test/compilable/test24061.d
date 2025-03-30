// https://issues.dlang.org/show_bug.cgi?id=24061

class Exception2
{
    this(string, int) {}
}

class E : Exception2
{
    this(int i)
    {
        scope (success) assert(0, "assume nothrow");
        super("hehe", 2);
    }
}
