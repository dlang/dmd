// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

/***************************************************/
// 14083

class NBase14083
{
    int foo(NA14083 a) { return 1; }
    int foo(NB14083 a) { return 2; }
}
class NA14083 : NBase14083
{
    int v;
    this(int v) { this.v = v; }
}
class NB14083 : NBase14083
{
    override int foo(NA14083 a) { return a.v; }
}

class TBase14083(T)
{
    int foo(TA14083!T a) { return 1; }
    int foo(TB14083!T a) { return 2; }
}
class TA14083(T) : TBase14083!T
{
    T v;
    this(T v) { this.v = v; }
}
class TB14083(T) : TBase14083!T
{
    override int foo(TA14083!T a) { return a.v; }
}

static assert(
{
    NA14083 na = new NA14083(10);
    NB14083 nb = new NB14083();
    assert(na.foo(na) == 1);
    assert(na.foo(nb) == 2);
    assert(nb.foo(na) == 10);

    TA14083!int ta = new TA14083!int(10);
    TB14083!int tb = new TB14083!int();
    assert(ta.foo(ta) == 1);
    assert(ta.foo(tb) == 2);
    assert(tb.foo(ta) == 10);

    return true;
}());
