// REQUIRED_ARGS: -check=nullderef=on
// PERMUTE_ARGS:

struct Struct
{
    int field;
}

void aLazyFunc(lazy int val)
{
    int storage = val;
}

void main()
{
    wrap!(() { Struct* ptr; int val = ptr.field; })(__LINE__);
    wrap!(() { int* ptr; int val = *ptr; })(__LINE__);
    wrap!(() { Object ptr; auto del = &ptr.toString; del(); })(__LINE__);
    wrap!(() { Object obj; obj.toString(); })(__LINE__);
    wrap!(() { void function() func; func(); })(__LINE__);
    wrap!(() { void delegate() del; del(); })(__LINE__);

    int val = 2;
    val.aLazyFunc();
}

void wrap(alias test)(int expectedLine)
{
    try
    {
        test();
        assert(0);
    }
    catch (Error e)
    {
        assert(e.line == expectedLine);
    }
}
