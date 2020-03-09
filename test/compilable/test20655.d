union U
{
    string s;
    int x;
}
U u;
static assert(is(typeof(() { auto s = u.s; }) ==
    void function () nothrow @nogc @system));
