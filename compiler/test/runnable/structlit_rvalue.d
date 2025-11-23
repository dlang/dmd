void refCounted(ProcessPipes val)
{
    val = ProcessPipes.init;
}

struct File
{
    private string _name;
    ~this() @safe {}
}

struct ProcessPipes
{
    enum Redirect{ stdin = 1 }
    Redirect _redirectFlags;
    File _stdin, _stdout;
}

void main()
{
	refCounted(ProcessPipes.init);
}
