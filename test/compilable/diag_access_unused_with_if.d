// REQUIRED_ARGS: -wi -unittest -vunused

/*
TEST_OUTPUT:
---
compilable/diag_access_unused_with_if.d(16): Warning: value assigned to `x` is never used
compilable/diag_access_unused_with_if.d(18):        overwritten here
compilable/diag_access_unused_with_if.d(19): Warning: returned expression is always `null`
---
*/

string f2b()
{
    string x;
    x ~= "a";                   // no warn
    x ~= "a";                   // warn
    string y;
    x = y;                      // warn
    return x;                   // warn, always null
}

string f1()
{
    string x;
    x ~= "a";                   // no warn
    if (x.length == 0)
        x ~= "a";
    else
        x ~= "a";
    x ~= "a";                   // no warn
    x ~= "a";
    return x;
}

string f2()
{
    string x;
    x ~= "a";                   // no warn
    x ~= "a";
    return x;
}

string f3()
{
    string x;
    x ~= "a";
    if (x.length == 0)
        x ~= "a";               // no warn
    return x;
}

string f4()
{
    string x;
    x ~= "a";
    if (x.length == 0)
        x ~= "a";               // no warn
    x ~= "a";                   // no warn
    return x;
}

string f5()
{
    string x;
    x ~= "a";
    if (x.length == 0)
        if (x.length == 1)
            x ~= "a";           // no warn
    return x;
}

string f6()
{
    string x;
    x ~= "a";
    if (x.length == 0)
    {
    }
    else
        x ~= "a";               // no warn
    return x;
}

string f7()
{
    string x;
    x ~= "a";
    if (x.length == 0)
        x ~= "a";               // no warn
    else
    {
    }
    return x;
}

string f8()
{
    string x;
    x ~= "a";                   // no warn
    if (x.length == 0)
        x ~= "a";
    else
        x ~= "a";
    return x;
}
