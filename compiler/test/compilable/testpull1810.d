// REQUIRED_ARGS: -c -w
/*
Warning removed in: https://github.com/dlang/dmd/pull/15568
---
fail_compilation/testpull1810.d(21): Warning: statement is not reachable
Error: warnings are treated as errors
       Use -wi if you wish to treat warnings only as informational.
---
*/

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
