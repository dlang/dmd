/*
 * Returning stack references from `@safe` code. `-preview=dip1000` must stay
 * off: escape.d would report some of these on its own, with other messages,
 * and the test is about what the fast engine reports.
 *
 * The `return arr[]` case is the exception: escape.d reports it without any
 * flag, so that one line in the expected output below is not ours.
 *
 * REQUIRED_ARGS: -preview=fastdfa
 * TEST_OUTPUT:
---
fail_compilation/fastdfa_stackescape.d(34): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(31):        A pointer to the cell of the variable `arr` has potentially escaped
fail_compilation/fastdfa_stackescape.d(39): Error: returning `arr[]` escapes a reference to local variable `arr`
fail_compilation/fastdfa_stackescape.d(47): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(44):        A pointer to the cell of the variable `arr` has potentially escaped
fail_compilation/fastdfa_stackescape.d(56): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(53):        A pointer to the cell of the variable `x` has potentially escaped
fail_compilation/fastdfa_stackescape.d(65): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(62):        A pointer to the cell of the variable `arr` has potentially escaped
fail_compilation/fastdfa_stackescape.d(74): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/fastdfa_stackescape.d(71):        A pointer to the cell of the variable `arr` has potentially escaped
---
*/
@safe:

/****************** issue 20508: slice of a local static array ******************/

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

/****************** address-of a local returned through a variable ************/

int* addressOfLocal()
{
    int x = 0;
    int* p = &x;
    return p;
}

/****************** address-of an element through a local slice ************/

int* elementAddressThroughLocalSlice()
{
    int[3] arr = [1, 2, 3];
    int[] s = arr[];
    return &s[0];
}

/****************** re-slice of a local slice ************/

int[] resliceOfLocalSlice()
{
    int[3] arr = [1, 2, 3];
    int[] s = arr[];
    return s[0 .. 2];
}
