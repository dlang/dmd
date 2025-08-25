// REQUIRED_ARGS: -w
// Warning removed in: https://github.com/dlang/dmd/pull/15568

uint foo(uint i)
{
    try
    {
        ++i;
        return 3;
    }
    catch (Exception e)
    {
    }
    return 4;
}
