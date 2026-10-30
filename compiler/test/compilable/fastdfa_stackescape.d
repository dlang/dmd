/*
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

class HasArray
{
    int[3] data;
}

int[] classArrayAlias(HasArray c)
{
    ref int[3] a = c.data;
    int[] s = a[];
    return s;
}

int[] classArrayAliasBounded(HasArray c)
{
    ref int[3] a = c.data;
    int[] s = a[1 .. 3];
    return s;
}

int[3] globalArray;

int[] globalArraySlice()
{
    int[] s = globalArray[];
    return s;
}

int[] globalArraySliceBounded()
{
    int[] s = globalArray[1 .. 3];
    return s;
}

// Ref parameters name caller storage rather than local parameter storage.
int[] refArraySlice(ref int[3] a)
{
    int[] s = a[];
    return s;
}

int[] refArraySliceBounded(ref int[3] a)
{
    int[] s = a[1 .. 3];
    return s;
}

int* refScalarAddress(ref int x)
{
    int* p = &x;
    return p;
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

// Escaping delegates keep captured storage alive.
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

// These return element values, not the local array's storage.
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

struct SliceHolder
{
    const(char)[][1] elem;

    ref const(char)[] opIndex(size_t i) scope return
    {
        return elem[i];
    }
}

// Copy a slice returned by ref; do not return its descriptor address.
const(char)[] copyRefSlice(const(char)[] input)
{
    auto holder = SliceHolder([input]);
    return holder[0];
}

const(char)[] copyRefSliceResliced(const(char)[] input)
{
    auto holder = SliceHolder([input]);
    return holder[0][];
}

const(char)[] copyRefSliceAlias(const(char)[] input)
{
    auto holder = SliceHolder([input]);
    ref const(char)[] aliasSlice = holder[0];
    auto copy = aliasSlice;
    return copy;
}

struct PointerHolder
{
    int* ptr;

    @property ref int* value() scope return
    {
        return ptr;
    }
}

int* copyRefPointer(int* input)
{
    auto holder = PointerHolder(input);
    return holder.value;
}

struct DynamicHolder
{
    int[] value;

    ref int[] get() scope return @safe
    {
        return value;
    }
}

int[] copyRefPropertyResliced(int[] input) @safe
{
    DynamicHolder holder = DynamicHolder(input);
    return holder.get()[];
}

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

struct View
{
    int[] values;
}

// Deferred: storing a slice in a struct field loses its root provenance.
int[] deferredStructFieldAssign()
{
    int[3] a = [1, 2, 3];
    View v;
    v.values = a[];
    return v.values;
}

// Deferred: the analyzer does not yet root slices created through `with`.
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

// Deferred: the variadic's backing storage belongs to the caller.
int[] deferredVariadicBacking(int[] args...)
{
    auto saved = args;
    return saved;
}

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
