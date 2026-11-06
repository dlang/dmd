// https://github.com/dlang/dmd/issues/18077
module issue18077;

// Case 1: Original pattern with valid pointer initialization
enum isHashable(T) = __traits(compiles, T.init.tupleof[0][0].sizeof);

struct SumType(Types...)
{
    union Storage
    {
        Types values;
    }

    Storage storage;

    static if (isHashable!(Types[0])) {}
}

string[] toLines(Expression val) {
    return [];
}

alias Expression = SumType!(Scope, Return);

struct Return {
    Expression* _expr = null;
}

struct Scope {
    Expression[] statements;

    string[] toLines() {
        return Expression.init.toLines;
    }
}

// Case 2: Swapped type order in SumType template arguments
alias Expression2 = SumType!(Return2, Scope2);

struct Return2 {
    Expression2* _expr;
}

struct Scope2 {
    Expression2[] statements;

    string[] toLines() {
        return Expression2.init.toLines;
    }
}

string[] toLines(Expression2 val) {
    return [];
}

// Case 3: Multiple recursive types in union storage with traits inspecting tupleof
struct MultiSumType(Types...)
{
    union Storage
    {
        Types values;
    }
    Storage storage;

    static if (__traits(compiles, Types[0].init.tupleof.length))
    {
        enum hasFields = true;
    }
}

alias MultiExpr = MultiSumType!(NodeA, NodeB, NodeC);

struct NodeA
{
    MultiExpr* next;
    int a;
}

struct NodeB
{
    MultiExpr[] children;
    string b;
}

struct NodeC
{
    MultiExpr* parent;
    MultiExpr* left;
    MultiExpr* right;
}

// Case 4: Nested templated aggregates with union storage
struct Outer(T)
{
    struct Inner
    {
        union U
        {
            T val;
            void* ptr;
        }
        U u;
    }
    Inner inner;
    static if (__traits(compiles, T.init.tupleof)) {}
}

alias RecursiveOuter = Outer!(OuterNode);

struct OuterNode
{
    RecursiveOuter* rec = null;
    int data;
}

// Case 5: Failed __traits(compiles) evaluation followed by successful semantic analysis
struct SpecSource
{
    SpecTarget t;
}

struct SpecTarget
{
    // During SpecTarget's semantic, check if SpecSource has a known size:
    enum sourceHasSize = __traits(compiles, SpecSource.sizeof);
    int value;
}

static assert(!SpecTarget.sourceHasSize);

void testSpeculativeRecovery()
{
    SpecSource src;
    static assert(SpecSource.sizeof == 4);
    assert(src.t.value == 0);
}

// Case 6: Classes and inherited aggregates with forward-referenced struct in union
class BaseClass
{
    int a;
    int b;
}

struct FwdClassField
{
    int payload;
}

class DerivedClass : BaseClass
{
    union
    {
        int tag;
        FwdClassField field;
    }
}

void testClassInheritance()
{
    DerivedClass d = new DerivedClass();
    assert(d !is null);
    d.tag = 42;
    assert(d.field.payload == 42);
}

// Case 7: Zero-init vs Non-zero-init struct fields with unanalyzed initializers
struct ZeroInitStruct
{
    int* p = null;
    int a = 0;
    bool b = false;
    double d = 0.0;
}

struct NonZeroInitStruct
{
    int* p = cast(int*)0x1234;
    int a = 42;
    bool b = true;
    double d = 3.14;
}

void testZeroInit()
{
    ZeroInitStruct z;
    assert(z.p is null);
    assert(z.a == 0);
    assert(z.b == false);
    assert(z.d == 0.0);

    NonZeroInitStruct nz;
    assert(nz.a == 42);
    assert(nz.b == true);
    assert(nz.d == 3.14);
}

// Case 8: Repeated aggregate size determination
void testRepeatedSize()
{
    static assert(Expression.sizeof == Expression.sizeof);
    static assert(MultiExpr.sizeof == MultiExpr.sizeof);
    static assert(RecursiveOuter.sizeof == RecursiveOuter.sizeof);
}

void main()
{
    Expression e;
    assert(e.toLines().length == 0);

    Expression2 e2;
    assert(e2.toLines().length == 0);

    MultiExpr me;
    static assert(MultiExpr.hasFields);

    RecursiveOuter ro;

    testSpeculativeRecovery();
    testClassInheritance();
    testZeroInit();
    testRepeatedSize();
}
