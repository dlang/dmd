// https://issues.dlang.org/show_bug.cgi?id=23407

struct Foo {    int x; };
_Static_assert(sizeof(struct Foo) == sizeof(int), "");

void one(void){
    struct Foo {
        int y, z;
    };
    struct Foo f = {0};
    _Static_assert(sizeof(struct Foo) == 2*sizeof(int), "");
}

void two(void){
    struct Foo {
        int y, z;
    }
    f
    ;
    _Static_assert(sizeof(f) == 2*sizeof(int), "");
    _Static_assert(sizeof(struct Foo) == 2*sizeof(int), ""); // fails
}
