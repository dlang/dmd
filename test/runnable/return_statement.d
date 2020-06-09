//PERMUTE_ARGS: -release -g -O
struct S
{
    __gshared int numDtor;
    int a;
    ~this() { ++numDtor; a = 0; }
    ref int val() return { return a; }
}

S make() { return S(2); }

int call() { return make().val; }
int literal() { return S(123).val; }
//------------
struct St
{
    int a;
    ~this() { a = 0; }
}
int foo() { return St(2).a; }
ref int passthrough(return ref int i) { return St(2).a ? i : i; }
//-------------
struct Str{
    int[8] a;
    ~this(){ a[] = 0; }
    ref val(){ return a; }
}
Str barz(){ return Str([2,2,2,2,2,2,2,2]); }
int[8] fooz(){ return barz.val; }

void main()
{
    assert(call() == 2);
    assert(literal() == 123);
    assert(S.numDtor == 2);
    int i;
    assert(&passthrough(i) == &i);
    assert(foo() == 2);

    assert(fooz() == [2,2,2,2,2,2,2,2]);
}