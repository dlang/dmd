// PERMUTE_ARGS: -inline
// https://github.com/dlang/dmd/issues/23909

enum E : int* { none = null }
enum Derived : E { none = E.none }
enum ConstPointer : const(int)* { none = null }
enum VoidPointer : void* { none = null }
struct Pair { int value; }
enum PairPointer : Pair* { none = null }
enum OtherPairPointer : Pair* { none = null }

bool f()
{
    int[4] a;
    E p = cast(E) a.ptr;
    return *p == 0;
}

static assert(f());

E asEnum(int* p) { return cast(E) p; }
int* asPointer(E p) { return cast(int*) p; }

bool scalarPointer()
{
    int value = 42;
    E p = asEnum(&value);
    assert(*p == 42);
    assert(p !is null);
    assert(cast(bool) p);
    if (!p)
        return false;
    assert(p is asEnum(&value));
    int other;
    assert(p !is asEnum(&other));
    *p = 10;
    assert(value == 10);
    assert(asPointer(p) == &value);
    return true;
}
static assert(scalarPointer());

bool arrayPointers()
{
    int[4] a = [10, 20, 30, 40];
    E p = asEnum(&a[1]);
    assert(*p == 20);
    assert(p[1] == 30);
    p[1] = 35;
    assert(a[2] == 35);
    auto next = p + 1;
    assert(*next == 35);
    assert((1 + p) is next);
    assert(next - p == 1);
    assert(p < next);
    ++p;
    assert(*p == 35);
    p -= 1;
    assert(*p == 20);

    E fromSlice = cast(E) a[1 .. 3];
    assert(fromSlice[1] == 35);

    Derived derived = cast(Derived) a.ptr;
    assert(derived[3] == 40);
    ConstPointer cp = cast(ConstPointer) a.ptr;
    assert(*cp == 10);
    return true;
}
static assert(arrayPointers());

immutable int globalValue = 73;

bool globalPointer()
{
    ConstPointer p = cast(ConstPointer) &globalValue;
    return *p == 73 && p !is null;
}
static assert(globalPointer());

bool voidAndNullPointers()
{
    int value = 123;
    VoidPointer vp = cast(VoidPointer) &value;
    E p = cast(E) vp;
    assert(*p == 123);

    E n = E.none;
    assert(n is null);
    assert(!cast(bool) n);
    assert(cast(int*) n is null);
    assert(cast(E) null == E.none);
    E zero = cast(E) 0;
    assert(zero is null);
    assert(!cast(bool) zero);
    if (zero)
        return false;
    E address = cast(E) 42;
    assert(address !is null);
    assert(cast(bool) address);
    return true;
}
static assert(voidAndNullPointers());

bool constEnumPointer()
{
    Pair value = Pair(5);
    const(PairPointer) p = cast(PairPointer) &value;
    return (*p).value == 5;
}
static assert(constEnumPointer());

// The enum must not allow pointer casts that CTFE otherwise rejects.
int invalidToEnum()
{
    float value = 1;
    float* p = &value;
    E ep = cast(E) p;
    return *ep;
}
static assert(!__traits(compiles, { enum result = invalidToEnum(); }));

float invalidFromEnum()
{
    int value = 1;
    E p = asEnum(&value);
    float* fp = cast(float*) p;
    return *fp;
}
static assert(!__traits(compiles, { enum result = invalidFromEnum(); }));

int invalidThroughVoidEnum()
{
    float value = 1;
    VoidPointer p = cast(VoidPointer) &value;
    E ep = cast(E) p;
    return *ep;
}
static assert(!__traits(compiles, { enum result = invalidThroughVoidEnum(); }));

int invalidConstEnumCast()
{
    Pair value = Pair(5);
    const(PairPointer) p = cast(PairPointer) &value;
    PairPointer mutablePointer = cast(PairPointer) p;
    return (*mutablePointer).value;
}
static assert(!__traits(compiles, { enum result = invalidConstEnumCast(); }));

int invalidConstEnumToOther()
{
    Pair value = Pair(5);
    const(PairPointer) p = cast(PairPointer) &value;
    OtherPairPointer mutablePointer = cast(OtherPairPointer) p;
    return (*mutablePointer).value;
}
static assert(!__traits(compiles, { enum result = invalidConstEnumToOther(); }));
