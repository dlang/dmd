// 4375: Dangling else

void main() {
    mixin(q{
        if(true)
            if(true)
                assert(54);
        else
            assert(55);
    });
}

