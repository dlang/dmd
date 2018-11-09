// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

void main() {
    if (true)
        final switch (1)    // o_O
            case 1:
                if (false)
                    assert(119);
    else
        assert(120);
}

