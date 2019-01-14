/*
Provides light-weight formatting utilities for pretty-printing
on assertion failures
*/
module core.internal.dassert;

// Yields the appropriate printf format token for a type T
// Indended to be used by miniFormat
private template getPrintfFormat(T)
{
    static if (is(T == long))
    {
        enum getPrintfFormat = "%lld";
    }
    else static if (is(T == ulong))
    {
        enum getPrintfFormat = "%llu";
    }
    else static if (__traits(isIntegral, T))
    {
        static if (__traits(isUnsigned, T))
        {
            enum getPrintfFormat = "%u";
        }
        else
        {
            enum getPrintfFormat = "%d";
        }
    }
    else
    {
        static assert(0, "Unknown format");
    }
}

/**
Minimalistic formatting for use in _d_assert_fail to keep the compilation
overhead small and avoid the use of Phobos.
*/
auto miniFormat(V)(auto ref V v)
{
    import core.stdc.stdio : sprintf;
    import core.stdc.string : strlen;
    static if (__traits(isIntegral, V))
    {
        enum printfFormat = getPrintfFormat!V;
        char[20] val;
        sprintf(val.ptr, printfFormat, v);
        return val.idup[0 .. strlen(val.ptr)];
    }
    else static if (__traits(isFloating, V))
    {
        char[60] val;
        sprintf(val.ptr, "%g", v);
        return val.idup[0 .. strlen(val.ptr)];
    }
    else static if (__traits(compiles, { string s = V.init.toString(); }))
    {
        return v.toString();
    }
    // anything string-like
    else static if (__traits(compiles, V.init ~ ""))
    {
        return `"` ~ v ~ `"`;
    }
    else static if (is(V : U[], U))
    {
        string msg = "[";
        foreach (i, ref el; v)
        {
            if (i > 0)
                msg ~= ", ";

            // don't fully print big arrays
            if (i >= 30)
            {
                msg ~= "...";
                break;
            }
            msg ~= miniFormat(el);
        }
        msg ~= "]";
        return msg;
    }
    else static if (is(V : Val[K], K, Val))
    {
        size_t i;
        string msg = "[";
        foreach (k, ref val; v)
        {
            if (i++ > 0)
                msg ~= ", ";
            // don't fully print big AAs
            if (i >= 30)
            {
                msg ~= "...";
                break;
            }
            msg ~= miniFormat(k) ~ ": " ~ miniFormat(val);
        }
        msg ~= "]";
        return msg;
    }
    else static if (is(V == struct))
    {
        string msg = V.stringof ~ "(";
        foreach (idx, mem; v.tupleof)
        {
            if (idx > 0)
                msg ~= ", ";
            msg ~= miniFormat(v.tupleof[idx]);
        }
        msg ~= ")";
        return msg;
    }
    else
    {
        return V.stringof;
    }
}

// Inverts a comparison token for use in _d_assert_fail
string invertCompToken(string comp)
{
    switch (comp)
    {
        case "==":
            return "!=";
        case "!=":
            return "==";
        case "<":
            return ">=";
        case "<=":
            return ">";
        case ">":
            return "<=";
        case ">=":
            return "<";
        case "is":
            return "!is";
        case "!is":
            return "is";
        case "in":
            return "!in";
        case "!in":
            return "in";
        default:
            assert(0, "Invalid comparison operator: " ~ comp);
    }
}

