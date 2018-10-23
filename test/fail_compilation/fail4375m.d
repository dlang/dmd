// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

void main() {
    do
        if (true)
            if (true)
                assert(76);
        else
            assert(77);
    while (false);
}

