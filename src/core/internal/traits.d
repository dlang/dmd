/**
 * Contains traits for runtime internal usage.
 *
 * Copyright: Copyright Digital Mars 2014 -.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC core/internal/_traits.d)
 */
module core.internal.traits;

/// taken from std.typetuple.TypeTuple
template TypeTuple(TList...)
{
    alias TypeTuple = TList;
}
alias AliasSeq = TypeTuple;

template FieldTypeTuple(T)
{
    static if (is(T == struct) || is(T == union))
        alias FieldTypeTuple = typeof(T.tupleof[0 .. $ - __traits(isNested, T)]);
    else static if (is(T == class))
        alias FieldTypeTuple = typeof(T.tupleof);
    else
    {
        alias FieldTypeTuple = TypeTuple!T;
    }
}

T trustedCast(T, U)(auto ref U u) @trusted pure nothrow
{
    return cast(T)u;
}

template Unconst(T)
{
         static if (is(T U ==   immutable U)) alias Unconst = U;
    else static if (is(T U == inout const U)) alias Unconst = U;
    else static if (is(T U == inout       U)) alias Unconst = U;
    else static if (is(T U ==       const U)) alias Unconst = U;
    else                                      alias Unconst = T;
}

/// taken from std.traits.Unqual
template Unqual(T)
{
    version (none) // Error: recursive alias declaration @@@BUG1308@@@
    {
             static if (is(T U ==     const U)) alias Unqual = Unqual!U;
        else static if (is(T U == immutable U)) alias Unqual = Unqual!U;
        else static if (is(T U ==     inout U)) alias Unqual = Unqual!U;
        else static if (is(T U ==    shared U)) alias Unqual = Unqual!U;
        else                                    alias Unqual =        T;
    }
    else // workaround
    {
             static if (is(T U ==          immutable U)) alias Unqual = U;
        else static if (is(T U == shared inout const U)) alias Unqual = U;
        else static if (is(T U == shared inout       U)) alias Unqual = U;
        else static if (is(T U == shared       const U)) alias Unqual = U;
        else static if (is(T U == shared             U)) alias Unqual = U;
        else static if (is(T U ==        inout const U)) alias Unqual = U;
        else static if (is(T U ==        inout       U)) alias Unqual = U;
        else static if (is(T U ==              const U)) alias Unqual = U;
        else                                             alias Unqual = T;
    }
}

// Substitute all `inout` qualifiers that appears in T to `const`
template substInout(T)
{
    static if (is(T == immutable))
    {
        alias substInout = T;
    }
    else static if (is(T : shared const U, U) || is(T : const U, U))
    {
        // U is top-unqualified
        mixin("alias substInout = "
            ~ (is(T == shared) ? "shared " : "")
            ~ (is(T == const) || is(T == inout) ? "const " : "")    // substitute inout to const
            ~ "substInoutForm!U;");
    }
    else
        static assert(0);
}

private template substInoutForm(T)
{
    static if (is(T == struct) || is(T == class) || is(T == union) || is(T == interface))
    {
        alias substInoutForm = T;   // prevent matching to the form of alias-this-ed type
    }
    else static if (is(T : V[K], K, V))        alias substInoutForm = substInout!V[substInout!K];
    else static if (is(T : U[n], U, size_t n)) alias substInoutForm = substInout!U[n];
    else static if (is(T : U[], U))            alias substInoutForm = substInout!U[];
    else static if (is(T : U*, U))             alias substInoutForm = substInout!U*;
    else                                       alias substInoutForm = T;
}

/// used to declare an extern(D) function that is defined in a different module
template externDFunc(string fqn, T:FT*, FT) if (is(FT == function))
{
    static if (is(FT RT == return) && is(FT Args == function))
    {
        import core.demangle : mangleFunc;
        enum decl = {
            string s = "extern(D) RT externDFunc(Args)";
            foreach (attr; __traits(getFunctionAttributes, FT))
                s ~= " " ~ attr;
            return s ~ ";";
        }();
        pragma(mangle, mangleFunc!T(fqn)) mixin(decl);
    }
    else
        static assert(0);
}

template staticIota(int beg, int end)
{
    static if (beg + 1 >= end)
    {
        static if (beg >= end)
        {
            alias staticIota = TypeTuple!();
        }
        else
        {
            alias staticIota = TypeTuple!(+beg);
        }
    }
    else
    {
        enum mid = beg + (end - beg) / 2;
        alias staticIota = TypeTuple!(staticIota!(beg, mid), staticIota!(mid, end));
    }
}

private struct __InoutWorkaroundStruct {}
@property T rvalueOf(T)(inout __InoutWorkaroundStruct = __InoutWorkaroundStruct.init);
@property ref T lvalueOf(T)(inout __InoutWorkaroundStruct = __InoutWorkaroundStruct.init);

// taken from std.traits.isAssignable
template isAssignable(Lhs, Rhs = Lhs)
{
    enum isAssignable = __traits(compiles, lvalueOf!Lhs = rvalueOf!Rhs) && __traits(compiles, lvalueOf!Lhs = lvalueOf!Rhs);
}

// taken from std.traits.isInnerClass
template isInnerClass(T) if (is(T == class))
{
    static if (is(typeof(T.outer)))
    {
        template hasOuterMember(T...)
        {
            static if (T.length == 0)
                enum hasOuterMember = false;
            else
                enum hasOuterMember = T[0] == "outer" || hasOuterMember!(T[1 .. $]);
        }
        enum isInnerClass = __traits(isSame, typeof(T.outer), __traits(parent, T)) && !hasOuterMember!(__traits(allMembers, T));
    }
    else
        enum isInnerClass = false;
}

/// Returns the type of `alias T` if it is not a type, or just returns `T`
/// if it is a type
private template Type(alias T)
{
    static if (is(typeof(T) == X, X))
    {
        alias Type = X;
    }
    else
    {
        alias Type = T;
    }
}

/// Detect whether type `T` is a static array.
template isStaticArray(alias T)
{
    enum isStaticArray = is(Type!T : U[N], U, size_t N) && __traits(getAliasThis, Type!T).length == 0;
}

///
@safe unittest
{
    static assert( isStaticArray!(int[3]));
    static assert( isStaticArray!(const(int)[5]));
    static assert( isStaticArray!(const(int)[][5]));

    static assert(!isStaticArray!(const(int)[]));
    static assert(!isStaticArray!(immutable(int)[]));
    static assert(!isStaticArray!(const(int)[4][]));
    static assert(!isStaticArray!(int[]));
    static assert(!isStaticArray!(int[char]));
    static assert(!isStaticArray!(int[1][]));
    static assert(!isStaticArray!(int[int]));
    static assert(!isStaticArray!int);

    // This should NOT be considered a static array
    struct AliasThisStaticArray
    {
        int[1] x;
        alias x this;
    }

    AliasThisStaticArray atsa;
    static assert(!isStaticArray!AliasThisStaticArray);
    static assert(!isStaticArray!atsa);

    // This is an enumeration of static array, so they are indeed static arrays.
    enum EnumStaticArray : int[2]
    {
        a = [1, 2],
        b = [2, 3]
    }

    static assert(isStaticArray!EnumStaticArray);
    static assert(isStaticArray!(EnumStaticArray.a));
    static assert(isStaticArray!(EnumStaticArray.b));

    int[1] x;

    static assert(isStaticArray!(x));
}

template dtorIsNothrow(T)
{
    enum dtorIsNothrow = is(typeof(function{T t=void;}) : void function() nothrow);
}

// taken from std.meta.allSatisfy
template allSatisfy(alias F, T...)
{
    static foreach (Ti; T)
    {
        static if (!is(typeof(allSatisfy) == bool) && // not yet defined
                   !F!(Ti))
        {
            enum allSatisfy = false;
        }
    }
    static if (!is(typeof(allSatisfy) == bool)) // if not yet defined
    {
        enum allSatisfy = true;
    }
}

// taken from std.meta.anySatisfy
template anySatisfy(alias F, T...)
{
    static foreach (Ti; T)
    {
        static if (!is(typeof(anySatisfy) == bool) && // not yet defined
                   F!(Ti))
        {
            enum anySatisfy = true;
        }
    }
    static if (!is(typeof(anySatisfy) == bool)) // if not yet defined
    {
        enum anySatisfy = false;
    }
}

// simplified from std.traits.maxAlignment
template maxAlignment(U...)
{
    static if (U.length == 0)
        static assert(0);
    else static if (U.length == 1)
        enum maxAlignment = U[0].alignof;
    else static if (U.length == 2)
        enum maxAlignment = U[0].alignof > U[1].alignof ? U[0].alignof : U[1].alignof;
    else
    {
        enum a = maxAlignment!(U[0 .. ($+1)/2]);
        enum b = maxAlignment!(U[($+1)/2 .. $]);
        enum maxAlignment = a > b ? a : b;
    }
}

// std.traits.Fields
template Fields(T)
{
    static if (is(T == struct) || is(T == union))
        alias Fields = typeof(T.tupleof[0 .. $ - __traits(isNested, T)]);
    else static if (is(T == class))
        alias Fields = typeof(T.tupleof);
    else
        alias Fields = TypeTuple!T;
}

// std.traits.hasElaborateDestructor
template hasElaborateDestructor(S)
{
    static if (isStaticArray!S && S.length)
    {
        enum bool hasElaborateDestructor = hasElaborateDestructor!(typeof(S.init[0]));
    }
    else static if (is(S == struct))
    {
        enum hasElaborateDestructor = __traits(hasMember, S, "__dtor")
            || anySatisfy!(.hasElaborateDestructor, Fields!S);
    }
    else
    {
        enum bool hasElaborateDestructor = false;
    }
}

// std.traits.hasElaborateCopyDestructor
template hasElaborateCopyConstructor(S)
{
    static if (isStaticArray!S && S.length)
    {
        enum bool hasElaborateCopyConstructor = hasElaborateCopyConstructor!(typeof(S.init[0]));
    }
    else static if (is(S == struct))
    {
        enum hasElaborateCopyConstructor = __traits(hasMember, S, "__xpostblit");
    }
    else
    {
        enum bool hasElaborateCopyConstructor = false;
    }
}

template hasElaborateAssign(S)
{
    static if (isStaticArray!S && S.length)
    {
        enum bool hasElaborateAssign = hasElaborateAssign!(typeof(S.init[0]));
    }
    else static if (is(S == struct))
    {
        enum hasElaborateAssign = is(typeof(S.init.opAssign(rvalueOf!S))) ||
                                  is(typeof(S.init.opAssign(lvalueOf!S))) ||
                                  anySatisfy!(.hasElaborateAssign, FieldTypeTuple!S);
    }
    else
    {
        enum bool hasElaborateAssign = false;
    }
}

// std.meta.Filter
template Filter(alias pred, TList...)
{
    static if (TList.length == 0)
    {
        alias Filter = TypeTuple!();
    }
    else static if (TList.length == 1)
    {
        static if (pred!(TList[0]))
            alias Filter = TypeTuple!(TList[0]);
        else
            alias Filter = TypeTuple!();
    }
    else
    {
        alias Filter =
            TypeTuple!(
                Filter!(pred, TList[ 0  .. $/2]),
                Filter!(pred, TList[$/2 ..  $ ]));
    }
}

// std.meta.staticMap
template staticMap(alias F, T...)
{
    static if (T.length == 0)
    {
        alias staticMap = TypeTuple!();
    }
    else static if (T.length == 1)
    {
        alias staticMap = TypeTuple!(F!(T[0]));
    }
    else
    {
        alias staticMap =
            TypeTuple!(
                staticMap!(F, T[ 0  .. $/2]),
                staticMap!(F, T[$/2 ..  $ ]));
    }
}

// std.exception.assertCTFEable
version (unittest) package(core)
void assertCTFEable(alias dg)()
{
    static assert({ cast(void) dg(); return true; }());
    cast(void) dg();
}

// std.traits.FunctionTypeOf
/*
Get the function type from a callable object `func`.

Using builtin `typeof` on a property function yields the types of the
property value, not of the property function itself.  Still,
`FunctionTypeOf` is able to obtain function types of properties.

Note:
Do not confuse function types with function pointer types; function types are
usually used for compile-time reflection purposes.
 */
template FunctionTypeOf(func...)
if (func.length == 1 /*&& isCallable!func*/)
{
    static if (is(typeof(& func[0]) Fsym : Fsym*) && is(Fsym == function) || is(typeof(& func[0]) Fsym == delegate))
    {
        alias FunctionTypeOf = Fsym; // HIT: (nested) function symbol
    }
    else static if (is(typeof(& func[0].opCall) Fobj == delegate))
    {
        alias FunctionTypeOf = Fobj; // HIT: callable object
    }
    else static if (is(typeof(& func[0].opCall) Ftyp : Ftyp*) && is(Ftyp == function))
    {
        alias FunctionTypeOf = Ftyp; // HIT: callable type
    }
    else static if (is(func[0] T) || is(typeof(func[0]) T))
    {
        static if (is(T == function))
            alias FunctionTypeOf = T;    // HIT: function
        else static if (is(T Fptr : Fptr*) && is(Fptr == function))
            alias FunctionTypeOf = Fptr; // HIT: function pointer
        else static if (is(T Fdlg == delegate))
            alias FunctionTypeOf = Fdlg; // HIT: delegate
        else
            static assert(0);
    }
    else
        static assert(0);
}

@safe unittest
{
    class C
    {
        int value() @property { return 0; }
    }
    static assert(is( typeof(C.value) == int ));
    static assert(is( FunctionTypeOf!(C.value) == function ));
}

@system unittest
{
    int test(int a);
    int propGet() @property;
    int propSet(int a) @property;
    int function(int) test_fp;
    int delegate(int) test_dg;
    static assert(is( typeof(test) == FunctionTypeOf!(typeof(test)) ));
    static assert(is( typeof(test) == FunctionTypeOf!test ));
    static assert(is( typeof(test) == FunctionTypeOf!test_fp ));
    static assert(is( typeof(test) == FunctionTypeOf!test_dg ));
    alias int GetterType() @property;
    alias int SetterType(int) @property;
    static assert(is( FunctionTypeOf!propGet == GetterType ));
    static assert(is( FunctionTypeOf!propSet == SetterType ));

    interface Prop { int prop() @property; }
    Prop prop;
    static assert(is( FunctionTypeOf!(Prop.prop) == GetterType ));
    static assert(is( FunctionTypeOf!(prop.prop) == GetterType ));

    class Callable { int opCall(int) { return 0; } }
    auto call = new Callable;
    static assert(is( FunctionTypeOf!call == typeof(test) ));

    struct StaticCallable { static int opCall(int) { return 0; } }
    StaticCallable stcall_val;
    StaticCallable* stcall_ptr;
    static assert(is( FunctionTypeOf!stcall_val == typeof(test) ));
    static assert(is( FunctionTypeOf!stcall_ptr == typeof(test) ));

    interface Overloads
    {
        void test(string);
        real test(real);
        int  test(int);
        int  test() @property;
    }
    alias ov = __traits(getVirtualFunctions, Overloads, "test");
    alias F_ov0 = FunctionTypeOf!(ov[0]);
    alias F_ov1 = FunctionTypeOf!(ov[1]);
    alias F_ov2 = FunctionTypeOf!(ov[2]);
    alias F_ov3 = FunctionTypeOf!(ov[3]);
    static assert(is(F_ov0* == void function(string)));
    static assert(is(F_ov1* == real function(real)));
    static assert(is(F_ov2* == int function(int)));
    static assert(is(F_ov3* == int function() @property));

    alias F_dglit = FunctionTypeOf!((int a){ return a; });
    static assert(is(F_dglit* : int function(int)));
}

// std.traits.ReturnType
/*
Get the type of the return value from a function,
a pointer to function, a delegate, a struct
with an opCall, a pointer to a struct with an opCall,
or a class with an `opCall`. Please note that $(D_KEYWORD ref)
is not part of a type, but the attribute of the function
(see template $(LREF functionAttributes)).
*/
template ReturnType(func...)
if (func.length == 1 /*&& isCallable!func*/)
{
    static if (is(FunctionTypeOf!func R == return))
        alias ReturnType = R;
    else
        static assert(0, "argument has no return type");
}

//
@safe unittest
{
    int foo();
    ReturnType!foo x;   // x is declared as int
}

@safe unittest
{
    struct G
    {
        int opCall (int i) { return 1;}
    }

    alias ShouldBeInt = ReturnType!G;
    static assert(is(ShouldBeInt == int));

    G g;
    static assert(is(ReturnType!g == int));

    G* p;
    alias pg = ReturnType!p;
    static assert(is(pg == int));

    class C
    {
        int opCall (int i) { return 1;}
    }

    static assert(is(ReturnType!C == int));

    C c;
    static assert(is(ReturnType!c == int));

    class Test
    {
        int prop() @property { return 0; }
    }
    alias R_Test_prop = ReturnType!(Test.prop);
    static assert(is(R_Test_prop == int));

    alias R_dglit = ReturnType!((int a) { return a; });
    static assert(is(R_dglit == int));
}

// std.traits.Parameters
/*
Get, as a tuple, the types of the parameters to a function, a pointer
to function, a delegate, a struct with an `opCall`, a pointer to a
struct with an `opCall`, or a class with an `opCall`.
*/
template Parameters(func...)
if (func.length == 1 /*&& isCallable!func*/)
{
    static if (is(FunctionTypeOf!func P == function))
        alias Parameters = P;
    else
        static assert(0, "argument has no parameters");
}

//
@safe unittest
{
    int foo(int, long);
    void bar(Parameters!foo);      // declares void bar(int, long);
    void abc(Parameters!foo[1]);   // declares void abc(long);
}

@safe unittest
{
    int foo(int i, bool b) { return 0; }
    static assert(is(Parameters!foo == AliasSeq!(int, bool)));
    static assert(is(Parameters!(typeof(&foo)) == AliasSeq!(int, bool)));

    struct S { real opCall(real r, int i) { return 0.0; } }
    S s;
    static assert(is(Parameters!S == AliasSeq!(real, int)));
    static assert(is(Parameters!(S*) == AliasSeq!(real, int)));
    static assert(is(Parameters!s == AliasSeq!(real, int)));

    class Test
    {
        int prop() @property { return 0; }
    }
    alias P_Test_prop = Parameters!(Test.prop);
    static assert(P_Test_prop.length == 0);

    alias P_dglit = Parameters!((int a){});
    static assert(P_dglit.length == 1);
    static assert(is(P_dglit[0] == int));
}
