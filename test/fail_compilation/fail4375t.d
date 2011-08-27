// REQUIRED_ARGS: -w
// 4375: Dangling else

unittest {  // disallowed
    if (true)
        if (false)
            assert(52);
    else
        assert(53);
}

