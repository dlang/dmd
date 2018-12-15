// REQUIRED_ARGS: -w -unittest
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

unittest {  // disallowed
    if (true)
        if (false)
            assert(52);
    else
        assert(53);
}

