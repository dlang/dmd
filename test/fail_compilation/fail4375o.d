// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

void main() {
    if (true)
        for (; false;)
            if (true)
                assert(82);
    else
        assert(83);
}

