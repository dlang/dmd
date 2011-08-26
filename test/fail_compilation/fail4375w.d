// 4375: Dangling else

static if (true)
    version (B)
        struct G1 {}
else
    struct G2 {}

