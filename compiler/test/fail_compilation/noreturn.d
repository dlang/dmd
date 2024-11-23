/*
REQUIRED_ARGS: -w -o-

TEST_OUTPUT:
---
fail_compilation/noreturn.d(73): Error: Accessed expression of type `noreturn`
    noreturn m = n;
                 ^
fail_compilation/noreturn.d(77):        called from here: `assign()`
enum forceAss = assign();
                      ^
fail_compilation/noreturn.d(84): Error: Accessed expression of type `noreturn`
    foo(n);
        ^
fail_compilation/noreturn.d(84):        called from here: `foo(n)`
    foo(n);
       ^
fail_compilation/noreturn.d(88):        called from here: `calling()`
enum forceCall = calling();
                        ^
fail_compilation/noreturn.d(94): Error: Accessed expression of type `noreturn`
    return arr[n ? n : n];
               ^
fail_compilation/noreturn.d(97):        called from here: `nested()`
enum forceNested = nested();
                         ^
fail_compilation/noreturn.d(103): Error: Accessed expression of type `noreturn`
        case 0: return cast(noreturn) i;
                                      ^
fail_compilation/noreturn.d(113):        called from here: `casting(0)`
enum forceCasting0 = casting(0);
                            ^
fail_compilation/noreturn.d(104): Error: Accessed expression of type `noreturn`
        case 1: return cast(typeof(assert(0))) cast(double) i;
                                                            ^
fail_compilation/noreturn.d(114):        called from here: `casting(1)`
enum forceCasting1 = casting(1);
                            ^
fail_compilation/noreturn.d(107): Error: Accessed expression of type `noreturn`
            return cast() n;
                          ^
fail_compilation/noreturn.d(115):        called from here: `casting(2)`
enum forceCasting2 = casting(2);
                            ^
fail_compilation/noreturn.d(155): Error: uncaught CTFE exception `object.Exception("")`
enum throwEnum = throw new Exception("");
                       ^
fail_compilation/noreturn.d(160): Error: Accessed expression of type `noreturn`
    return a;
           ^
fail_compilation/noreturn.d(163):        called from here: `func()`
enum f = func();
             ^
---
https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1034.md
https://issues.dlang.org/show_bug.cgi?id=23063
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

noreturn casting(int i)
{
    final switch (i)
    {
        case 0: return cast(noreturn) i;
        case 1: return cast(typeof(assert(0))) cast(double) i;
        case 2, 3: {
            noreturn n;
            return cast() n;
        }
    }
    assert(false);
}

enum forceCasting0 = casting(0);
enum forceCasting1 = casting(1);
enum forceCasting2 = casting(2);

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

enum throwEnum = throw new Exception("");

noreturn func()
{
    noreturn a;
    return a;
}

enum f = func();
