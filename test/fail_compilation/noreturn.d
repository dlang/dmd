/*
REQUIRED_ARGS: -w -o-

TEST_OUTPUT:
---
fail_compilation/noreturn.d(39): Error: `"Accessed expression of type `noreturn`"`
fail_compilation/noreturn.d(43):        called from here: `assign()`
fail_compilation/noreturn.d(50): Error: `"Accessed expression of type `noreturn`"`
fail_compilation/noreturn.d(50):        called from here: `foo(n)`
fail_compilation/noreturn.d(54):        called from here: `calling()`
fail_compilation/noreturn.d(60): Error: `"Accessed expression of type `noreturn`"`
fail_compilation/noreturn.d(63):        called from here: `nested()`
fail_compilation/noreturn.d(73): Deprecation: `n` has no effect
fail_compilation/noreturn.d(69): Error: `"Accessed expression of type `noreturn`"`
fail_compilation/noreturn.d(79):        called from here: `casting(0)`
fail_compilation/noreturn.d(70): Error: `"Accessed expression of type `noreturn`"`
fail_compilation/noreturn.d(80):        called from here: `casting(1)`
fail_compilation/noreturn.d(73): Error: `"Accessed expression of type `noreturn`"`
fail_compilation/noreturn.d(81):        called from here: `casting(2)`
fail_compilation/noreturn.d(121): Error: uncaught CTFE exception `object.Exception("")`
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


/*
https://issues.dlang.org/show_bug.cgi?id=23063

TEST_OUTPUT:
---
fail_compilation/noreturn.d(135): Error: `"Accessed expression of type `noreturn`"`
fail_compilation/noreturn.d(138):        called from here: `func()`
---
*/
noreturn func()
{
    noreturn a;
    return a;
}

enum f = func();
