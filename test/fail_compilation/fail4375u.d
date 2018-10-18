// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

static if (true)
    static if (false)
        struct G1 {}
else
    struct G2 {}

