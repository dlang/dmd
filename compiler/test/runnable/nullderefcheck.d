// REQUIRED_ARGS: -check=nullderef=on

struct Struct
{
    int field;
}

void main()
{
    wrap!(() { Struct* ptr; int val = ptr.field; })(__LINE__);
    wrap!(() { int* ptr; int val = *ptr; })(__LINE__);
    wrap!(() { Object ptr; auto del = &ptr.toString; del(); })(__LINE__);
    wrap!(() { Object obj; obj.toString(); })(__LINE__);
    //wrap!(() { void function() func; func(); })(__LINE__);
    //wrap!(() { void delegate() del; del(); })(__LINE__);
}

void wrap(alias test)(int expectedLine)
{
    gotFile = null;
    gotLine = 0;
    try
    {
        test();
    }
    catch (Error)
    {
    }
    assert(gotFile == __FILE__);
    assert(gotLine == expectedLine);
}

string gotFile;
uint gotLine;

extern (C) void _d_nullpointerp(immutable(char*) file, uint line)
{
    import core.stdc.string : strlen;

    gotFile = file[0 .. strlen(file)];
    gotLine = line;
    throw new Error("");
}
