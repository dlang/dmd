//https://issues.dlang.org/show_bug.cgi?id=22291

alias AliasSeq(T...) = T;
void noParameters()
{
    static assert(typeof(__traits(arguments)).length == 0);
}
void noArgs()
{
    //Arguments are not valid, this should not compile
    static assert(!__traits(compiles, __traits(arguments, 456)));
}
shared static this()
{
    static assert(typeof(__traits(arguments)).length == 0);
}
int echoPlusOne(int x)
{
    __traits(arguments)[0] += 1;
    return x;
}
static assert(echoPlusOne(1) == 2);
class Tree {
    int opApply(int delegate(size_t, Tree) dg) {
        if (dg(0, this)) return 1;
        return 0;
    }
}
void useOpApply(Tree top, int x)
{
    foreach(idx; 0..5)
    {
        static assert(is(typeof(__traits(arguments)) == AliasSeq!(Tree, int)));
    }
    foreach(idx, elem; top)
    {
        static assert(is(typeof(__traits(arguments)) == AliasSeq!(size_t, Tree)));
    }
}
class Test
{
    static assert(!__traits(compiles, __traits(arguments)));
    void handle(int x)
    {
        static assert(typeof(__traits(arguments)).length == 1);
    }
}

int add(int x, int y)
{
	return x + y;
}

auto forwardToAdd(int x, int y)
{
	return add(__traits(arguments));
}
static assert(forwardToAdd(2, 3) == 5);
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
alias lambda = (x) => typeof(__traits(arguments)).stringof;
static assert(lambda(1) == "(int)");
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

