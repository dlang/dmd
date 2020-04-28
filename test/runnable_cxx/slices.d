/*
REQUIRED_ARGS: -extern-std=c++11
EXTRA_CPP_SOURCES: slices.cpp
CXXFLAGS(windows): /I..\src\dmd\root
CXXFLAGS(osx linux freebsd openbsd netbsd dragonflybsd solaris): -std=c++11 -I../src/dmd/root
*/

void main()
{
    ints([1]);
    cints([2, 3]);
    ccints([4, 5, 6]);

    paddedInts(33, [44], 55, [66]);

    char[] arr = cast(char[]) "Hello";
    version (Windows) {}
    else
    {
        int[] values = [1];
        int[] ret = wrap(values.ptr, cast(int) values.length);
        assert(ret is values);

        assert(passthrough(arr) == arr);
    }

    assert(passthroughRef(arr) is arr);

    structs([S(1, 2)]);
}

extern (C++):

// Check correct handling of qualifiers
void ints(int[]);
void cints(const(int)[]);
void ccints(const int[]);

//  Break "accidental" ABI compatibility
void paddedInts(byte, int[], short, int[]);

// Check D -> C++ -> D  works as well
version (Windows)
{
    /*
    Wrong return type mangling on windows:

    E.g.  <char[] passthrough(char[])>
    Expected: ?passthrough@@YAU?$__dslice@D@@U1@@Z
    Actual:   ?passthrough@@YA?AU?$__dslice@D@@U1@@Z

    Probably (related to) https://issues.dlang.org/show_bug.cgi?id=20679
    */
}
else
{
    int[] wrap(int*, int);
    char[] passthrough(char[]);
}

ref char[] passthroughRef(ref char[]);

// Complex types should be supported as well
struct S
{
    int a, b;
}

void structs(S[]);
