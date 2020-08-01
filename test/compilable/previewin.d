/* REQUIRED_ARGS: -preview=dip1000 -preview=in
 */

import core.stdc.time;

void fun(in int* inParam) @safe;
static assert([__traits(getParameterStorageClasses, fun, 0)] == ["in"]);
static assert (is(typeof(fun) P == __parameters) && is(P[0] == const int*));


void test()
{
    withDefaultValue(42);
    withDefaultValue();
    withDefaultRef(TimeRef.init);
    withDefaultRef();

    withInitDefaultValue();
    withInitDefaultRef();
}

struct FooBar
{
    string toString() const
    {
        string result;
        // Type inference works
        this.toString((buf) { result ~= buf; });
        // Specifying the STC too
        this.toString((in buf) { result ~= buf; });
        // Some covariance
        this.toString((const scope buf) { result ~= buf; });
        this.toString((scope const(char)[] buf) { result ~= buf; });
        this.toString((scope const(char[]) buf) { result ~= buf; });
        return result;
    }

    void toString(scope void delegate(in char[]) sink) const
    {
        sink("Hello world");
    }
}

// Ensure that default parameter works even if non CTFEable
void withDefaultValue(in time_t currTime = time(null)) {}
struct TimeRef { time_t now; ulong[4] bloat; }
void withDefaultRef(in TimeRef currTime = TimeRef(time(null))) {}

// Ensure that default parameters work with `.init`
void withInitDefaultValue(in size_t defVal = size_t.init) {}
void withInitDefaultRef(in TimeRef defVal = TimeRef.init) {}

// Ensure that temporary aren't needlessly created
// (if they are, it'll trigger the "goto skips declaration" error)
void checkNotIdentity(in void* p1, in void* p2) { assert(p1 !is p2); }
void checkTemporary()
{
    int* p = new int;
    if (p is null)
        goto LError;
    // Should not generate temporary, pass the pointers by value
    checkNotIdentity(/*lvalue*/ p, /*rvalue*/ null);
    checkNotIdentity(new int, null);
LError:
    assert(0);
}
