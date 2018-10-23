// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

void main() {
    auto x = 1;
    if (true)
        with (x)
            if (false)
                assert(90);
    else
        assert(91);
}

