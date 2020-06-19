// REQUIRED_ARGS: -main
// https://issues.dlang.org/show_bug.cgi?id=17712

struct Bytecode
{
    uint data;
}

@trusted ctSub(U)(string format, U args)
{
    import std.conv : to;
    foreach (i; format)
        return  format~ to!string(args);
    return format;
}

struct CtContext
{
    import std.uni : CodepointSet;

    CodepointSet[] charsets;

    string ctAtomCode(Bytecode[] ir)
    {
        string code;
        switch (code)
        {
            OrChar:
                code ~=  ``;
                for (uint i ; i ;)
                    code ~= ctSub(``, ir[i].data);
                charsets[ir[0].data].toSourceCode;
                break;

            default:
                assert(0);
        }
        return code;
    }
}
