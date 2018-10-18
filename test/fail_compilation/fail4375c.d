// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

void main() {
    if (true)
        if (false) {
            assert(6.1);
        }
    else {
        assert(6.2);
    }
}

