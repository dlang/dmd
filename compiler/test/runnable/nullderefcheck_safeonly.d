// REQUIRED_ARGS: -check=nullderef=safeonly
// PERMUTE_ARGS:

struct Struct
{
    int field;
}

void main()
{
    wrap!(() @safe { Struct* ptr; int val = ptr.field; })(__LINE__);
    wrap!(() @safe { int* ptr; int val = *ptr; })(__LINE__);
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
