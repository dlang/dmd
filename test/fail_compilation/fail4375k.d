// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

void main() {
    mixin(q{
        if(true)
            if(true)
                assert(54);
        else
            assert(55);
    });
}

