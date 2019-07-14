// https://issues.dlang.org/show_bug.cgi?id=20049
import core.stdc.stdio : fprintf, stderr;

class C
{
    this() nothrow {}
    ~this() nothrow {}
}

void main() nothrow
{
    auto c = new C;
    destroy(c);
    fprintf(stderr, "success.\n");
}
