// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

void main() {
    switch (4) {
        default:
            if (true)   // disallowed
                if (false)
                    assert(48);
            else
                assert(49);
            break;
    }
}

