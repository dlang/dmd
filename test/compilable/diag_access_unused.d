// REQUIRED_ARGS: -wi -unittest -diagnose=access

/*
TEST_OUTPUT:
---
compilable/diag_access_unused.d(134): Warning: unused local variable `x` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(134): Warning: unused public variable `x` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(134): Warning: unmodified public variable `x` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(135): Warning: unused local variable `y` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(135): Warning: unused public variable `y` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(135): Warning: unmodified public variable `y` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(153): Warning: value assigned to public variable `x` of function is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(151): Warning: unused modified public variable `x` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(152): Warning: unused local variable `y` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(152): Warning: unused public variable `y` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(152): Warning: unmodified public variable `y` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(166): Warning: unused local variable `x` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(166): Warning: unused public variable `x` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(166): Warning: unmodified public variable `x` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(269): Warning: unmodified public variable `x` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(272): Warning: unused local constant `x` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(275): Warning: unused local immutable `x` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(282): Warning: unused local variable `x` of unittest, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(282): Warning: unused public variable `x` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(282): Warning: unmodified public variable `x` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(310): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(309): Warning: unused modified public variable `x` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(86): Warning: unused private struct `PS`
compilable/diag_access_unused.d(86): Warning: unused public field `impl` of private struct, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(87): Warning: unused private variable `xc` of module `diag_access_unused`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(88): Warning: unused private class `PC`
compilable/diag_access_unused.d(88): Warning: unused public field `impl` of private class, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(97): Warning: unused private enum `PrivateEnum1`
compilable/diag_access_unused.d(99): Warning: unused member (enumerator) `a` of private enum `PrivateEnum1`
compilable/diag_access_unused.d(100): Warning: unused member (enumerator) `b` of private enum `PrivateEnum1`
compilable/diag_access_unused.d(101): Warning: unused member (enumerator) `c` of private enum `PrivateEnum1`
compilable/diag_access_unused.d(106): Warning: unused member (enumerator) `b` of private enum `PrivateEnum2`
compilable/diag_access_unused.d(107): Warning: unused member (enumerator) `c` of private enum `PrivateEnum2`
compilable/diag_access_unused.d(112): Warning: unused private alias `PrivateUnusedInt` of module `diag_access_unused`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(119): Warning: unused private alias `PrivateUInt` of module `diag_access_unused`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(129): Warning: unused private variable `px` of module `diag_access_unused`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(134): Warning: unused local variable `x` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(135): Warning: unused local variable `y` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(142): Warning: unused nested function `unusedNestedFun`
compilable/diag_access_unused.d(149): Warning: unused private function `privateUnusedFun` of module
compilable/diag_access_unused.d(152): Warning: unused local variable `y` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(166): Warning: unused local variable `x` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(177): Warning: unused private field `y` of public struct, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(183): Warning: unused private field `y` of public class, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(186): Warning: unused private struct `PrivateStruct`
compilable/diag_access_unused.d(188): Warning: unused public field `x` of private struct, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(191): Warning: unused private class `PrivateClass`
compilable/diag_access_unused.d(193): Warning: unused public field `x` of private class, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(206): Warning: unused private struct `S`
compilable/diag_access_unused.d(208): Warning: unused private function `privateMember` of private struct
compilable/diag_access_unused.d(209): Warning: unused public function `publicMember` of private struct
compilable/diag_access_unused.d(213): Warning: unused private function `privateMember` of public struct
compilable/diag_access_unused.d(216): Warning: unused private class `C`
compilable/diag_access_unused.d(218): Warning: unused private function `privateMember` of private class
compilable/diag_access_unused.d(219): Warning: unused public function `publicMember` of private class
compilable/diag_access_unused.d(223): Warning: unused private function `privateMember` of public class
compilable/diag_access_unused.d(226): Warning: unused private interface `PIP`
compilable/diag_access_unused.d(226): Warning: unused private class `PIP`
compilable/diag_access_unused.d(228): Warning: unused private function `privateMember` of private interface
compilable/diag_access_unused.d(229): Warning: unused public function `publicMember` of private interface
compilable/diag_access_unused.d(233): Warning: unused private function `privateMember` of public interface
compilable/diag_access_unused.d(238): Warning: unused private function `privateMember` of public interface
compilable/diag_access_unused.d(246): Warning: unused private class `Derived`
compilable/diag_access_unused.d(248): Warning: unused public function `member` of private class
compilable/diag_access_unused.d(254): Warning: unused private template `TS(uint n_)`
compilable/diag_access_unused.d(258): Warning: unused private template `TC(uint n_)`
compilable/diag_access_unused.d(262): Warning: unused private template `T(uint n)`
compilable/diag_access_unused.d(272): Warning: unused variable `x` in match expression of if statement, replace with `3` to silence
compilable/diag_access_unused.d(275): Warning: unused variable `x` in match expression of if statement, replace with `3` to silence
compilable/diag_access_unused.d(282): Warning: unused local variable `x` of unittest, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(283): Warning: unused local variable `y` of unittest, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused.d(286): Warning: unused parameter `x` of function, pass type `int` only by removing or commenting out name `x` to silence
compilable/diag_access_unused.d(297): Warning: unused parameter `x` of function, pass type `int` only by removing or commenting out name `x` to silence
compilable/diag_access_unused.d(303): Warning: unused parameter `x` of function, pass type `int` only by removing or commenting out name `x` to silence
compilable/diag_access_unused.d(313): Warning: unused private struct `SomeUncopyable`
---
*/

extern(C)
{
    private struct PS { void* impl; } // unused, but may be used externally
    private int xc;                   // unused, but may be used externally
    private class PC { void* impl; }  // unused, but may be used externally
}

public enum PublicEnum
{
    a,
    b,
    c
}
private enum PrivateEnum1       // unused
{
    a,                          // unused
    b,                          // unused
    c                           // unused
}
private enum PrivateEnum2        // used
{
    a,                          // referenced in alias `Pa`
    b,                          // unused
    c                           // unused
}
alias Pa = PrivateEnum2.a;

public alias PublicUnusedInt = int;
private alias PrivateUnusedInt = int; // unused

public alias PublicUsedInt = int;
private alias PrivateUsedInt = int;

version (D_LP64)
{
    private alias PrivateUInt = uint; // unused
    alias UInt = int;
}
else
{
    private alias PrivateUInt = uint;
    alias UInt = int;
}

public int x = 42;
private int px = 42;            // unused

void unusedFun()
{
labelA:                         // TODO: unused
    PublicUsedInt x;            // unused
    PrivateUsedInt y;           // unused
}

void usedFun()
{
    void usedNestedFun()
    {
        void unusedNestedFun()  // unused
        {
        }
    }
    usedNestedFun();
}

private void privateUnusedFun() // unused
{
    PublicUsedInt x;
    PrivateUsedInt y;           // unused
    x = x.init;
}

private void privateUsedFun()
{
}

static void usedFunStatic()
{
}

void main()
{
    int x;                      // unused
    // int y = xx;
    usedFun();
    privateUsedFun();
    usedFunStatic();
    // auto i = isDynamicArray!(int);
}

struct PublicStruct
{
    int x;
    private int y;              // unused
}

public class PublicClass
{
    int x;
    private int y;              // unused
}

private struct PrivateStruct    // unused
{
    int x;                      // unused
}

private class PrivateClass      // unused
{
    int x;                      // unused
}

private extern(C++) class PrivateExternCxxClass // TODO: no warn (can be called from C++)
{
    int x;
}

public extern(C++) class PublicExternCxxClass // no warn (can be called from C++)
{
    private int x;
}

private struct S                // unused
{
    private void privateMember(); // unused
    public void publicMember(); // unused
}
public struct SP
{
    private void privateMember(); // unused
    public void publicMember();
}
private class C                 // unused
{
    private void privateMember(); // unused
    public void publicMember();   // unused
}
public class CP
{
    private void privateMember(); // unused
    public void publicMember();
}
private interface PIP            // unused
{
    private void privateMember(); // unused
    public void publicMember(); // unused
}
public interface IP
{
    private void privateMember(); // unused
    public void publicMember();
}
interface I
{
    private void privateMember(); // unused
    public void publicMember();
}

private class Base
{
    void member();              // used by `Derived.member()`
}
private class Derived : Base    // unused
{
    override void member()      // unused
    {
        super.member();
    }
}

private struct TS(uint n_)      // unused
{
    alias n = n_;
}
private class TC(uint n_)       // unused
{
    alias n = n_;
}
private template T(uint n)      // unused
{
    alias N = n;
}

void fun() @safe pure
{
    if (auto x = 3)             // unused
    {
    }
    if (const x = 3)            // unused
    {
    }
    if (immutable x = 3)        // unused
    {
    }
}

@safe pure unittest
{
    int x = 42;                 // unused
    static int y = 42;          // unused
}

void functionWithUnusedParam1(int x) // unused parameter
{
}

void functionWithUnusedParam2(int) // excluding name silences warning
{
}

class StandardClass
{
    void virtualMemberWithAnonParam(int) {} // excluding name silences warning
    final void finalMemberWithUnusedParam(int x) {} // unused parameter
}

final class FinalClass
{
    void virtualMemberWithAnonParam(int) {} // excluding name silences warning
    final void finalMemberWithUnusedParam(int x) {} // unused parameter
}

// modify
@safe pure unittest
{
    int x = 42;
    x = 43;                     // modified
}

private struct SomeUncopyable
{
    int _x;                     // avoid warning with named prefixed with underscore
}

/***********************************
 * Create a new associative array of the same size and copy the contents of the
 * associative array into it.
 * Params:
 *      aa =     The associative array.
 */
V[K] dup(T : V[K], K, V)(T aa)
{
    //pragma(msg, "K = ", K, ", V = ", V);

    // Bug10720 - check whether V is copyable
    static assert(is(typeof({ V v = aa[K.init]; })),
        "cannot call " ~ T.stringof ~ ".dup because " ~ V.stringof ~ " is not copyable");

    V[K] result;

    //foreach (k, ref v; aa)
    //    result[k] = v;  // Bug13701 - won't work if V is not mutable

    ref V duplicateElem(ref K k, ref const V v) @trusted pure nothrow
    {
        import core.stdc.string : memcpy;

        void* pv = _aaGetY(cast(AA*)&result, typeid(V[K]), V.sizeof, &k);
        memcpy(pv, &v, V.sizeof);
        return *cast(V*)pv;
    }

    static if (__traits(hasPostblit, V))
    {
        auto postblit = _getPostblit!V();
        foreach (k, ref v; aa)
            postblit(duplicateElem(k, v));
    }
    else
    {
        foreach (k, ref v; aa)
            duplicateElem(k, v);
    }

    return result;
}
