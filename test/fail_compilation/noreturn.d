/*
REQUIRED_ARGS: -w -o-

TEST_OUTPUT:
---
fail_compilation\noreturn.d(32): Error: `"Accessed variable of type `noreturn`!"`
fail_compilation\noreturn.d(36):        called from here: `assign()`
fail_compilation\noreturn.d(43): Error: `"Accessed variable of type `noreturn`!"`
fail_compilation\noreturn.d(43):        called from here: `foo(n)`
fail_compilation\noreturn.d(47):        called from here: `calling()`
fail_compilation\noreturn.d(53): Error: `"Accessed variable of type `noreturn`!"`
fail_compilation\noreturn.d(56):        called from here: `nested()`
---

https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1034.md
*/

alias noreturn = typeof(*null);

int pass()
{
    noreturn n;
    noreturn m;
    return 0;
}

enum forcePass = pass();

int assign()
{
    noreturn n;
    noreturn m = n;
    return 0;
}

enum forceAss = assign();

void foo(const noreturn) {}

int calling()
{
    noreturn n;
    foo(n);
    return 0;
}

enum forceCall = calling();

int nested()
{
    int[4] arr;
    noreturn n;
    return arr[n ? n : n];
}

enum forceNested = nested();

/*
struct HasNoreturnStruct
{
    noreturn n;
}

int inStruct()
{
    HasNoreturnStruct hn;
    return hn.n;
}

enum forceInStruct = inStruct();

class HasNoreturnClass
{
    noreturn n;
}

int inClass()
{
    HasNoreturnClass hn = new HasNoreturnClass();
    return hn.n;
}

enum forceInClass = inClass();

int inClassRef()
{
    static void byRef(ref noreturn n) {}
    HasNoreturnClass hn = new HasNoreturnClass();
    byRef(hn.n);
    return 0;
}

enum forceInClassRef = inClassRef();
*/
