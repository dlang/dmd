// https://issues.dlang.org/show_bug.cgi?id=13552

struct S
{
    int x;
    @disable this(this);
    alias x this;
}

void main() {
    S s;
    int i = s;
    auto j = s;
    static assert(is(typeof(j) == int));
}
