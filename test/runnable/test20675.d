// https://issues.dlang.org/show_bug.cgi?id=20675

struct D
{
    int pos;
    char* p;
}

void test(scope ref D d) @safe
{
    D[] da;
    const pos = d.pos;
    da ~= D(pos, null);
    da ~= D(d.pos, null);
}

void main() @safe
{
    D d;
    test(d);
}
