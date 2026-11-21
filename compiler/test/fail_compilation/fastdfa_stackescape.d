/*
 * REQUIRED_ARGS: -preview=fastdfa
 * TEST_OUTPUT:
---
fail_compilation/fastdfa_stackescape.d(41): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(38):        A pointer to the cell of the variable `arr` has potentially escaped
fail_compilation/fastdfa_stackescape.d(46): Error: returning `arr[]` escapes a reference to local variable `arr`
fail_compilation/fastdfa_stackescape.d(54): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(51):        A pointer to the cell of the variable `arr` has potentially escaped
fail_compilation/fastdfa_stackescape.d(61): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(58):        A pointer to the cell of the variable `arr` has potentially escaped
fail_compilation/fastdfa_stackescape.d(68): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(65):        A pointer to the cell of the variable `arr` has potentially escaped
fail_compilation/fastdfa_stackescape.d(76): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(73):        A pointer to the cell of the variable `arr` has potentially escaped
fail_compilation/fastdfa_stackescape.d(83): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(80):        A pointer to the cell of the variable `arr` has potentially escaped
fail_compilation/fastdfa_stackescape.d(91): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(88):        A pointer to the cell of the variable `p` has potentially escaped
fail_compilation/fastdfa_stackescape.d(98): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(95):        A pointer to the cell of the variable `s` has potentially escaped
fail_compilation/fastdfa_stackescape.d(105): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(101):        A pointer to the cell of the variable `x` has potentially escaped
fail_compilation/fastdfa_stackescape.d(111): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(107):        A pointer to the cell of the variable `arr` has potentially escaped
fail_compilation/fastdfa_stackescape.d(123): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(120):        A pointer to the cell of the variable `x` has potentially escaped
fail_compilation/fastdfa_stackescape.d(130): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(127):        A pointer to the cell of the variable `a` has potentially escaped
fail_compilation/fastdfa_stackescape.d(148): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(145):        A pointer to the cell of the variable `h` has potentially escaped
---
*/
@safe:

int[] viaStaticArrayVariable()
{
    int[3] arr = [1, 2, 3];
    int[] s = arr[];
    return s;
}

int[] viaStaticArrayDirect()
{
    int[3] arr = [1, 2, 3];
    return arr[]; // also caught by the legacy checker without any flags
}

int[] viaStaticArrayBounded()
{
    int[3] arr = [1, 2, 3];
    int[] s = arr[1 .. 3];
    return s;
}

int* elementAddressThroughLocalSlice()
{
    int[3] arr = [1, 2, 3];
    int[] s = arr[];
    return &s[0];
}

int[] resliceOfLocalSlice()
{
    int[3] arr = [1, 2, 3];
    int[] s = arr[];
    return s[0 .. 2];
}

// Slicing returns local array storage, even when its elements are pointers.
int*[] pointerArraySlice()
{
    int*[1] arr = [null];
    int*[] s = arr[];
    return s;
}

int*[] pointerArraySliceBounded()
{
    int*[1] arr = [null];
    int*[] s = arr[0 .. 1];
    return s;
}

// The address escapes the local holder, not the heap contents it holds.
int** localPointerAddress()
{
    int* p = new int;
    int** q = &p;
    return q;
}

int[]* localSliceAddress()
{
    int[] s = new int[3];
    int[]* p = &s;
    return p;
}

// By-value parameters have local storage, unlike ref parameters.
int* valueScalarAddress(int x)
{
    int* p = &x;
    return p;
}

int[] valueArraySlice(int[3] arr)
{
    int[] s = arr[];
    return s;
}

ref T identity(T)(return ref T x)
{
    return x;
}

int* localPointerThroughRef()
{
    int x;
    int* p = &x;
    return identity(p);
}

int[] localSliceThroughRef()
{
    int[3] a;
    int[] p = a[];
    return identity(p);
}

struct InlineHolder
{
    int[3] data;

    ref int[3] get() scope return
    {
        return data;
    }
}

// Slicing the ref result still aliases the holder's inline storage.
int[] inlineArrayThroughRef()
{
    InlineHolder h;
    auto s = h.get()[];
    return s;
}
