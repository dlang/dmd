/*
 * Positive tests for the fastdfa stack-escape check: none of these may error
 * under `-preview=fastdfa` without `-preview=dip1000`.
 *
 * REQUIRED_ARGS: -preview=fastdfa
 */
@safe:

int[] returnHeap()
{
    return new int[3];
}

int[] returnHeapVariable()
{
    int[] h = new int[3];
    int[] t = h;
    return t;
}

int[] returnParameter(int[] a)
{
    return a;
}

void consume(int[] a)
{
}

int[] passStackSlice()
{
    int[3] arr = [1, 2, 3];
    consume(arr[]);
    return new int[3];
}

int sumOfLocal()
{
    int[3] arr = [1, 2, 3];
    int total;
    foreach (v; arr[])
        total += v;
    return total;
}

int[3] returnStaticArrayByValue()
{
    int[3] arr;
    arr[] = [1, 2, 3];
    return arr;
}

struct HasStatic
{
    int[3] data;
}

HasStatic returnStaticArrayInStruct()
{
    int[3] arr;
    arr[] = [1, 2, 3];
    return HasStatic(arr);
}

/****************** value returns: no indirections, cannot escape ***************/

int sliceIndexValue()
{
    int[3] s = [1, 2, 3];
    int[] t = s[];
    return t[0];
}

int sliceIndexSum()
{
    int[3] s = [1, 2, 3];
    int[] t = s[];
    return t[2] + t[1];
}

struct P
{
    int v;
}

P sliceIndexInStruct()
{
    int[3] s = [1, 2, 3];
    int[] t = s[];
    return P(t[0]);
}

/****************** @system / @trusted exemptions *****************************/

@system int[] systemViaIntermediate()
{
    int[3] arr = [1, 2, 3];
    int[] t = arr[];
    return t;
}

@trusted int[] trustedViaIntermediate()
{
    int[3] arr = [1, 2, 3];
    int[] t = arr[];
    return t;
}

/****************** nested capture consumed in this frame *********************/

int consumeNestedCaptureInFrame()
{
    int[3] a = [7, 8, 9];
    int[] g()
    {
        int[] t = a[];
        return t;
    }
    auto s = g();
    return s[1];
}

/****************** captures and holders of references **********************/

// A capture's storage is a heap closure or an outer frame, not this frame.
void delegate() captureSink;

void capturedInEscapedClosure()
{
    int[3] a = [1, 2, 3];
    void g()
    {
        int[] use()
        {
            return a[];
        }
    }

    captureSink = &g;
    int[] use2()
    {
        return a[];
    }
}

// An element read out of a static array of references is a value copy, and
// the cell is a holder of references: not an escape of the cell itself.
int* elementOfStaticArrayOfPointers()
{
    int*[3] a = [null, null, null];
    int*[] t = a[];
    return t[0];
}

int[] elementOfStaticArrayOfSlices()
{
    int[][3] a = [null, null, null];
    int[][] t = a[];
    return t[0];
}

/****************** reassignment away from stack data ****************/

int globalInt;

// A pointer reassigned to global data no longer points at the stack.
int* reassignPointerToGlobal()
{
    int x = 0;
    int* p = &x;
    p = &globalInt;
    return p;
}

// A slice reassigned to another array no longer aliases the static array.
int[] reassignSliceToOther()
{
    int[3] arr = [1, 2, 3];
    int[] s = arr[];
    int[] h = [1, 2];
    s = h;
    return s;
}

// A pointer reassigned to heap data no longer points at the stack.
int* reassignPointerToHeap()
{
    int x = 0;
    int* p = &x;
    int* h = new int;
    p = h;
    return p;
}

/****************** known deferrals (future work, not covered) ****************/

// Deferred: a slice stored through a struct field assignment does not yet
// root the field's value at the local; this real escape slips through.
struct View
{
    int[] values;
}

int[] deferredStructFieldAssign()
{
    int[3] a = [1, 2, 3];
    View v;
    v.values = a[];
    return v.values;
}

// Deferred: slices produced inside `with` are not rooted at the local yet.
int[] deferredWith()
{
    struct W
    {
        int[3] b;
    }

    W w;
    with (w)
    {
        int[] q = b[];
        return q;
    }
}

// Deferred: issue 20509, a typesafe variadic's backing storage lives in the
// caller's frame.
int[] returnVariadicBacking(int[] args...)
{
    auto saved = args;
    return saved;
}

void useVariadic()
{
    auto arr = returnVariadicBacking(1, 2, 3);
    assert(arr == [1, 2, 3]);
}

/****************** valid code pinned by the call-site regressions ***************/

// utf.d(789) `toUTF16z`: the address of an element of a heap-backed slice.
const(wchar)* heapElementAddress()
{
    wchar[] r = new wchar[4];
    return &r[0];
}

const(wchar)* appendedElementAddress()
{
    wchar[] r;
    r.reserve(4);
    r ~= 'a';
    r ~= '\0';
    return &r[0];
}

// The address of an element of an associative array's storage.
int* aaElementAddress()
{
    int[int] aa;
    aa[1] = 2;
    return &aa[1];
}

// utf.d(410) `decode`: a value returned from a `scope` parameter.
pure dchar decodeValueFromScope(const scope dchar[] s)
{
    return cast(dchar) s[0];
}

// A value read out of a `scope` parameter slice: not a reference.
pure int plainValueFromScope(const scope int[] s, ref size_t idx)
{
    return s[idx];
}
