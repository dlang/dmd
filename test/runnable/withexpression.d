// https://issues.dlang.org/show_bug.cgi?id=21538
// REQUIRED_ARGS: -preview=withExpressions

//This is a runnable test so the final code generation is tested properly

struct Type
{
    int x;
    int y;
}
class Test
{
    int x;
    this(int i)
    {
        x = i;
    }
}
struct HasStatic
{
    static int chimpanzee = 299;
}
Type grab()
{
    return Type(45, 100);
}
//grab() but counts how many times it was called
static int count = 0;
Type countingGrab()
{
    ++count;
    return grab();
}
void testThunk(alias fun)(const int res)
{
    assert(fun() == res);
}
int inc(const int x)
{
    return x + 1;
}
int main()
{
    const t = Type(4, 5);
    const int res = with(t)(x + y);
    assert(res == 9);

    testThunk!(() => with(grab())(x + y))(145);

    testThunk!(() => with(countingGrab())(x + y))(145);
    assert(count == 1);

    Type l, r;
    with(l) with(r) y = 420;
    assert(l.y == 0);
    assert(r.y == 420);

    const int xyz = with(new Test(420)) x;
    assert(xyz==420);

    Type viaPtr = Type(2, 3);
    with(&viaPtr) {
        x = 420;
    }
    assert((with(&viaPtr) x) == 420);

    with(HasStatic)
    {
        chimpanzee = 420;
    }
    const int moo = with(HasStatic()) chimpanzee;
    assert(moo == 420);

    testThunk!(() => with(grab()) inc(x))(46);
    return 0;
}