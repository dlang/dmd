// REQUIRED_ARGS: -preview=dtorfields

/******************************************
 * https://issues.dlang.org/show_bug.cgi?id=20934
 */
struct HasDtor
{
    ~this() {}
}

struct Disable
{
    HasDtor member;
    this() @disable;
}

extern(C++) class Extern
{
    HasDtor member;
    this();
}

/******************************************
 * https://issues.dlang.org/show_bug.cgi?id=21213
 */
class Parent
{
    this() nothrow pure @nogc @safe {}
}

class Child : Parent
{
    HasDtor member;
}
