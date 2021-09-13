//https://issues.dlang.org/show_bug.cgi?id=22291

alias AliasSeq(T...) = T;
class Test
{
    static assert(!__traits(compiles, __traits(arguments)));
    void handle(int x)
    {
        static assert(typeof(__traits(arguments)).length == 1);
    }
}
void noParameters()
{
    static assert(typeof(__traits(arguments)).length == 0);
}
struct TestConstructor
{
    int x;
    string y;
    //This parameter will not have a name but it's (tuple) members
    //will
    this(typeof(this.tupleof))
    {
        this.tupleof = __traits(arguments);
    }
}
bool test(int x, string y)
{
    auto s = TestConstructor(2, "pi");
    return s.x == x && s.y == y;
}
static assert(test(2, "pi"));
int testNested(int x)
{
    static assert(typeof(__traits(arguments)).length == 1);
    int add(int x, int y)
    {
        static assert(typeof(__traits(arguments)).length == 2);
        return x + y;
    }
    return add(x + 2, x + 3);
}
void testPack(Pack...)(Pack x)
{
    static assert(is(typeof(__traits(arguments)) == typeof(AliasSeq!(x))));
}

ref int forwardTest(return ref int x)
{
    static assert(__traits(isRef, x) == __traits(isRef, __traits(arguments)[0]));
    return x;
}

int testRefness(int x, ref int monkey)
{
    {
        //monkey = x;
        __traits(arguments)[1] = __traits(arguments)[0];
    }
    return x;
}
int refTest()
{
    int x;
    testRefness(45, x);
    return x;
}
static assert(refTest() == 45);
T testTemplate(T)(scope T input)
{
    void chimpInASuit(float set)
    {
        static assert(is(typeof(__traits(arguments)) == AliasSeq!(float)));
    }
    {
        __traits(arguments) = AliasSeq!(T.max);
    }
    __traits(arguments) = AliasSeq!(T.init);
    return input;
}

static assert(testTemplate!long(420) == 0);

