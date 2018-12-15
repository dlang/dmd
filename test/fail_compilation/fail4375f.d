// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

void main() {
    version (A)
        version (B)
            assert(25.1);
    else
        assert(25.2);
}

