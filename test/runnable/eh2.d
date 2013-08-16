// PERMUTE_ARGS: -fPIC

extern(C) int printf(const char*, ...);

class Abc : Throwable
{
    this() pure
    {
        super("");
    }
    static int x;
    int a,b,c;

    synchronized void test()
    {
        printf("test 1\n");
        x |= 1;
        foo();
        printf("test 2\n");
        x |= 2;
    }

    shared void foo()
    {
        printf("foo 1\n");
        x |= 4;
        throw this;
        printf("foo 2\n");
        x |= 8;
    }
}

struct RefCounted
{
    void *p;
    ~this()
    {
        p = null;
    }
}

struct S
{
    RefCounted _data;

    int get() @property
    {
        throw new Exception("");
    }
}

void b9438()
{
    try
    {
        S s;
        S().get;
    }
    catch (Exception e){ }
}

struct File
{
    private struct Impl
    {
        uint refs = uint.max / 2;
    }
    private Impl* _p;
    private string _name;

    this(string name, in char[] stdioOpenmode = "rb")
    {
       _p = new Impl();
       _p.refs = 1;
       throw new Exception(name);
    }

    ~this() {
        assert(_p.refs);
        --_p.refs;
        _p = null;
    }

    int byLine() {
        return 0;
    }
}

void b10723() {
    try {
        int f = File("It's OK").byLine();
    } catch(Exception e) { }
}

int main()
{
    printf("hello world\n");
    auto a = new shared(Abc)();
    printf("hello 2\n");
    Abc.x |= 0x10;

    try
    {
        Abc.x |= 0x20;
        a.test();
        Abc.x |= 0x40;
    }
    catch (shared(Abc) b)
    {
        Abc.x |= 0x80;
        printf("Caught %p, x = x%x\n", b, Abc.x);
        assert(a is b);
        assert(Abc.x == 0xB5);
    }
    printf("Success!\n");
    b9438();
    b10723();
    return 0;
}
