/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/traits.d, _traits.d)
 * Documentation:  https://dlang.org/phobos/dmd_traits.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/traits.d
 */

module dmd.traits;

import core.stdc.stdio;
import core.stdc.string;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.canthrow;
import dmd.dclass;
import dmd.declaration;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.dtemplate;
import dmd.errors;
import dmd.expression;
import dmd.expressionsem;
import dmd.func;
import dmd.globals;
import dmd.hdrgen;
import dmd.id;
import dmd.identifier;
import dmd.mtype;
import dmd.nogc;
import dmd.root.array;
import dmd.root.speller;
import dmd.root.stringtable;
import dmd.target;
import dmd.tokens;
import dmd.typesem;
import dmd.visitor;
import dmd.root.rootobject;

enum LOGSEMANTIC = false;

/************************ TraitsExp ************************************/

// callback for TypeFunction::attributesApply
struct PushAttributes
{
    Expressions* mods;

    extern (C++) static int fp(void* param, const(char)* str)
    {
        PushAttributes* p = cast(PushAttributes*)param;
        p.mods.push(new StringExp(Loc.initial, cast(char*)str));
        return 0;
    }
}

/**************************************
 * Convert `Expression` or `Type` to corresponding `Dsymbol`, additionally
 * stripping off expression contexts.
 *
 * Some symbol related `__traits` ignore arguments expression contexts.
 * For example:
 * ----
 *  struct S { void f() {} }
 *  S s;
 *  pragma(msg, __traits(isNested, s.f));
 *  // s.f is `DotVarExp`, but `__traits(isNested)`` needs a `FuncDeclaration`.
 * ----
 *
 * This is used for that common `__traits` behavior.
 *
 * Input:
 *      oarg     object to get the symbol for
 * Returns:
 *      Dsymbol  the corresponding symbol for oarg
 */
private Dsymbol getDsymbolWithoutExpCtx(RootObject oarg)
{
    if (auto e = isExpression(oarg))
    {
        if (e.op == TOK.dotVariable)
            return (cast(DotVarExp)e).var;
        if (e.op == TOK.dotTemplateDeclaration)
            return (cast(DotTemplateExp)e).td;
    }
    return getDsymbol(oarg);
}

extern (C++) __gshared StringTable traitsStringTable;

/**
If the arguments are all either types that are arithmetic types,
or expressions that are typed as arithmetic types, then $(D true)
is returned.
Otherwise, $(D false) is returned.
If there are no arguments, $(D false) is returned.

---
import std.stdio;

void main()
{
    int i;
    writeln(__traits(isArithmetic, int));
    writeln(__traits(isArithmetic, i, i+1, int));
    writeln(__traits(isArithmetic));
    writeln(__traits(isArithmetic, int*));
}
---

    $(P Prints:)

$(CONSOLE
true
true
false
false
)
*/
enum isArithmetic = "isArithmetic";

/**
Works like $(D isArithmetic), except it's for floating
point types (including imaginary and complex types).
*/
enum isFloating = "isFloating";

/**
Works like $(D isArithmetic), except it's for integral
types (including character types).
*/
enum isIntegral = "isIntegral";

/**
Works like $(D isArithmetic), except it's for scalar types.
*/
enum isScalar = "isScalar";

/**
Works like $(D isArithmetic), except it's for unsigned types.
*/
enum isUnsigned = "isUnsigned";

/**
Works like $(D isArithmetic), except it's for static array types.
*/
enum isStaticArray = "isStaticArray";

/**
Works like $(D isArithmetic), except it's for associative array types.
*/
enum isAssociativeArray = "isAssociativeArray";

/**
If the arguments are all either types that are abstract classes,
or expressions that are typed as abstract classes, then $(D true)
is returned.
Otherwise, $(D false) is returned.
If there are no arguments, $(D false) is returned.

---
import std.stdio;

abstract class C { int foo(); }

void main()
{
    C c;
    writeln(__traits(isAbstractClass, C));
    writeln(__traits(isAbstractClass, c, C));
    writeln(__traits(isAbstractClass));
    writeln(__traits(isAbstractClass, int*));
}
---

    $(P Prints:)

$(CONSOLE
true
true
false
false
)
*/
enum isAbstractClass = "isAbstractClass";

/**
Checks whether a given symbols is `deprecated`.
*/
enum isDeprecated = "isDeprecated";

/**
Takes one argument and returns `true` if it's a function declaration
marked with `@disable`.

---
struct Foo
{
    @disable void foo();
    void bar(){}
}

static assert(__traits(isDisabled, Foo.foo));
static assert(!__traits(isDisabled, Foo.bar));
---

    $(P For any other declaration even if `@disable` is a syntactically valid
    attribute `false` is returned because the annotation has no effect.)

---
@disable struct Bar{}

static assert(!__traits(isDisabled, Bar));
---
*/
enum isDisabled = "isDisabled";

/**
Takes one argument. It returns `true` if the argument is a symbol
marked with the `@future` keyword, otherwise `false`. Currently, only
functions and variable declarations have support for the `@future` keyword.
*/
enum isFuture = "isFuture";

/**
Works like $(D isAbstractClass), except it's for final classes.
*/
enum isFinalClass = "isFinalClass";

/**
Takes one argument, which must be a type. It returns
$(D true) if the type is a $(DDSUBLINK glossary, pod, POD) type, otherwise $(D false).
*/
enum isPOD = "isPOD";

/**
Takes one argument.
It returns $(D true) if the argument is a nested type which internally
stores a context pointer, otherwise it returns $(D false).
Nested types can be  $(DDSUBLINK spec/class, nested, classes),
$(DDSUBLINK spec/struct, nested, structs), and
$(DDSUBLINK spec/function, variadicnested, functions).
*/
enum isNested = "isNested";

/**
The same as $(GLINK isVirtualMethod), except
that final functions that don't override anything return true.
*/
enum isVirtualFunction = "isVirtualFunction";

/**
Takes one argument. If that argument is a virtual function,
$(D true) is returned, otherwise $(D false).
Final functions that don't override anything return false.

---
import std.stdio;

struct S
{
    void bar() { }
}

class C
{
    void bar() { }
}

void main()
{
    writeln(__traits(isVirtualMethod, C.bar));  // true
    writeln(__traits(isVirtualMethod, S.bar));  // false
}
---
*/
enum isVirtualMethod = "isVirtualMethod";

/**
Takes one argument. If that argument is an abstract function,
$(D true) is returned, otherwise $(D false).

---
import std.stdio;

struct S
{
    void bar() { }
}

class C
{
    void bar() { }
}

class AC
{
    abstract void foo();
}

void main()
{
    writeln(__traits(isAbstractFunction, C.bar));   // false
    writeln(__traits(isAbstractFunction, S.bar));   // false
    writeln(__traits(isAbstractFunction, AC.foo));  // true
}
---
*/
enum isAbstractFunction = "isAbstractFunction";

/**
Takes one argument. If that argument is a final function,
$(D true) is returned, otherwise $(D false).

---
import std.stdio;

struct S
{
    void bar() { }
}

class C
{
    void bar() { }
    final void foo();
}

final class FC
{
    void foo();
}

void main()
{
    writeln(__traits(isFinalFunction, C.bar));  // false
    writeln(__traits(isFinalFunction, S.bar));  // false
    writeln(__traits(isFinalFunction, C.foo));  // true
    writeln(__traits(isFinalFunction, FC.foo)); // true
}
---
*/
enum isFinalFunction = "isFinalFunction";

/**
Takes one argument. If that argument is a function marked with
$(D_KEYWORD override), $(D true) is returned, otherwise $(D false).

---
import std.stdio;

class Base
{
    void foo() { }
}

class Foo : Base
{
    override void foo() { }
    void bar() { }
}

void main()
{
    writeln(__traits(isOverrideFunction, Base.foo)); // false
    writeln(__traits(isOverrideFunction, Foo.foo));  // true
    writeln(__traits(isOverrideFunction, Foo.bar));  // false
}
---
*/
enum isOverrideFunction = "isOverrideFunction";

/**
Takes one argument. If that argument is a static function,
meaning it has no context pointer,
$(D true) is returned, otherwise $(D false).
*/
enum isStaticFunction = "isStaticFunction";


/**
Takes one argument. If that argument is a declaration,
$(D true) is returned if it is $(D_KEYWORD ref), otherwise $(D false).

---
void fooref(ref int x)
{
    static assert(__traits(isRef, x));
    static assert(!__traits(isOut, x));
    static assert(!__traits(isLazy, x));
}
---
*/
enum isRef = "isRef";

/**
Takes one argument. If that argument is a declaration,
$(D true) is returned if it is $(D_KEYWORD out), otherwise $(D false).

---
void fooout(out int x)
{
    static assert(!__traits(isRef, x));
    static assert(__traits(isOut, x));
    static assert(!__traits(isLazy, x));
}
---
*/
enum isOut = "isOut";

/**
Takes one argument. If that argument is a declaration,
$(D true) is returned if it is $(D_KEYWORD lazy), otherwise $(D false).

---
void foolazy(lazy int x)
{
    static assert(!__traits(isRef, x));
    static assert(!__traits(isOut, x));
    static assert(__traits(isLazy, x));
}
---
*/
enum isLazy = "isLazy";

/**
Takes one argument which must either be a function symbol, function literal,
a delegate, or a function pointer.
It returns a `bool` which is `true` if the return value of the function is
returned on the stack via a pointer to it passed as a hidden extra
parameter to the function.

---
struct S { int[20] a; }
int test1();
S test2();

static assert(__traits(isReturnOnStack, test1) == false);
static assert(__traits(isReturnOnStack, test2) == true);
---

$(IMPLEMENTATION_DEFINED
    This is determined by the function ABI calling convention in use,
    which is often complex.
)

$(BEST_PRACTICE This has applications in:
$(OL
$(LI Returning values in registers is often faster, so this can be used as
a check on a hot function to ensure it is using the fastest method.)
$(LI When using inline assembly to correctly call a function.)
$(LI Testing that the compiler does this correctly is normally hackish and awkward,
this enables efficient, direct, and simple testing.)
))
*/
enum isReturnOnStack = "isReturnOnStack";

/**
Takes one argument. If that argument is a template then $(D true) is returned,
otherwise $(D false).

---
void foo(T)(){}
static assert(__traits(isTemplate,foo));
static assert(!__traits(isTemplate,foo!int()));
static assert(!__traits(isTemplate,"string"));
---
*/
enum isTemplate = "isTemplate";

/**
The first argument is a type that has members, or
is an expression of a type that has members.
The second argument is a string.
If the string is a valid property of the type,
$(D true) is returned, otherwise $(D false).

---
import std.stdio;

struct S
{
    int m;
}

void main()
{
    S s;

    writeln(__traits(hasMember, S, "m")); // true
    writeln(__traits(hasMember, s, "m")); // true
    writeln(__traits(hasMember, S, "y")); // false
    writeln(__traits(hasMember, int, "sizeof")); // true
}
---
*/
enum hasMember = "hasMember";

/**
Takes one argument, a symbol. Returns the identifier
for that symbol as a string literal.
*/
enum identifier = "identifier";

/**
Takes one argument, a symbol of aggregate type.
If the given aggregate type has $(D alias this), returns a list of
$(D alias this) names, by a tuple of $(D string)s.
Otherwise returns an empty tuple.
*/
enum getAliasThis = "getAliasThis";

/**
Takes one argument, a symbol. Returns a tuple of all attached user defined attributes.
If no UDA's exist it will return an empty tuple.


For more information, see: $(DDSUBLINK spec/attribute, uda, User Defined Attributes)

---
@(3) int a;
@("string", 7) int b;

enum Foo;
@Foo int c;

pragma(msg, __traits(getAttributes, a));
pragma(msg, __traits(getAttributes, b));
pragma(msg, __traits(getAttributes, c));
---

Prints:

$(CONSOLE
tuple(3)
tuple("string", 7)
tuple((Foo))
)
*/
enum getAttributes = "getAttributes";

/**
Takes one argument which must either be a function symbol, or a type
 is a function, delegate or a function pointer.

It returns a string identifying the kind of
$(LINK2 function.html#variadic, variadic arguments) that are supported.


$(TABLE2 getFunctionVariadicStyle,
    $(THEAD string returned, kind, access, example)
    $(TROW $(D "none"), not a variadic function, &nbsp;, $(D void foo();))
    $(TROW $(D "argptr"), D style variadic function, $(D _argptr) and $(D _arguments), $(D void bar(...)))
    $(TROW $(D "stdarg"), C style variadic function, $(LINK2 $(ROOT_DIR)phobos/core_stdc_stdarg.html, $(D core.stdc.stdarg)), $(D extern (C) void abc(int, ...)))
    $(TROW $(D "typesafe"), typesafe variadic function, array on stack, $(D void def(int[] ...)))
)

---
import core.stdc.stdarg;

void novar() {}
extern(C) void cstyle(int, ...) {}
extern(C++) void cppstyle(int, ...) {}
void dstyle(...) {}
void typesafe(int[]...) {}

static assert(__traits(getFunctionVariadicStyle, novar) == "none");
static assert(__traits(getFunctionVariadicStyle, cstyle) == "stdarg");
static assert(__traits(getFunctionVariadicStyle, cppstyle) == "stdarg");
static assert(__traits(getFunctionVariadicStyle, dstyle) == "argptr");
static assert(__traits(getFunctionVariadicStyle, typesafe) == "typesafe");

static assert(__traits(getFunctionVariadicStyle, (int[] a...) {}) == "typesafe");
static assert(__traits(getFunctionVariadicStyle, typeof(cstyle)) == "stdarg");
---
*/
enum getFunctionVariadicStyle = "getFunctionVariadicStyle";

/**
Takes one argument which must either be a function symbol, function literal,
or a function pointer. It returns a string tuple of all the attributes of
that function $(B excluding) any user defined attributes (UDAs can be
retrieved with the $(RELATIVE_LINK2 get-attributes, getAttributes) trait).
If no attributes exist it will return an empty tuple.

$(B Note:) The order of the attributes in the returned tuple is
implementation-defined and should not be relied upon.


A list of currently supported attributes are:
$(UL $(LI $(D pure), $(D nothrow), $(D @nogc), $(D @property), $(D @system), $(D @trusted), $(D @safe), and $(D ref)))
$(B Note:) $(D ref) is a function attribute even though it applies to the return type.


Additionally the following attributes are only valid for non-static member functions:
$(UL $(LI $(D const), $(D immutable), $(D inout), $(D shared)))


For example:

---
int sum(int x, int y) pure nothrow { return x + y; }

// prints ("pure", "nothrow", "@system")
pragma(msg, __traits(getFunctionAttributes, sum));

struct S
{
    void test() const @system { }
}

// prints ("const", "@system")
pragma(msg, __traits(getFunctionAttributes, S.test));
---

    $(P Note that some attributes can be inferred. For example:)

---
// prints ("pure", "nothrow", "@nogc", "@trusted")
pragma(msg, __traits(getFunctionAttributes, (int x) @trusted { return x * 2; }));
---
*/
enum getFunctionAttributes = "getFunctionAttributes";

/**
Takes one argument, which is a declaration symbol, or the type of a function,
delegate, or pointer to function.
Returns a string representing the $(LINK2 attribute.html#LinkageAttribute, LinkageAttribute)
of the declaration.
The string is one of:

$(UL
    $(LI $(D "D"))
    $(LI $(D "C"))
    $(LI $(D "C++"))
    $(LI $(D "Windows"))
    $(LI $(D "Pascal"))
    $(LI $(D "Objective-C"))
    $(LI $(D "System"))
)

---
extern (C) int fooc();
alias aliasc = fooc;

static assert(__traits(getLinkage, fooc) == "C");
static assert(__traits(getLinkage, aliasc) == "C");
---
*/
enum getLinkage = "getLinkage";

/**
Takes two arguments, the second must be a string.
The result is an expression formed from the first
argument, followed by a $(SINGLEQUOTE .), followed by the second
argument as an identifier.

---
import std.stdio;

struct S
{
    int mx;
    static int my;
}

void main()
{
    S s;

    __traits(getMember, s, "mx") = 1;  // same as s.mx=1;
    writeln(__traits(getMember, s, "m" ~ "x")); // 1

    __traits(getMember, S, "mx") = 1;  // error, no this for S.mx
    __traits(getMember, S, "my") = 2;  // ok
}
---
*/
enum getMember = "getMember";

/**
The first argument is an aggregate (e.g. struct/class/module).
The second argument is a string that matches the name of
one of the functions in that aggregate.
The result is a tuple of all the overloads of that function.

---
import std.stdio;

class D
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 2; }
}

void main()
{
    D d = new D();

    foreach (t; __traits(getOverloads, D, "foo"))
        writeln(typeid(typeof(t)));

    alias b = typeof(__traits(getOverloads, D, "foo"));
    foreach (t; b)
        writeln(typeid(t));

    auto i = __traits(getOverloads, d, "foo")[1](1);
    writeln(i);
}
---

    $(P Prints:)

$(CONSOLE
void()
int()
void()
int()
2
)
*/
enum getOverloads = "getOverloads";

/**
Takes two arguments.
The first must either be a function symbol, or a type
that is a function, delegate or a function pointer.
The second is an integer identifying which parameter, where the first parameter is
0.
It returns a tuple of strings representing the storage classes of that parameter.

---
ref int foo(return ref const int* p, scope int* a, out int b, lazy int c);

static assert(__traits(getParameterStorageClasses, foo, 0)[0] == "return");
static assert(__traits(getParameterStorageClasses, foo, 0)[1] == "ref");

static assert(__traits(getParameterStorageClasses, foo, 1)[0] == "scope");
static assert(__traits(getParameterStorageClasses, foo, 2)[0] == "out");
static assert(__traits(getParameterStorageClasses, typeof(&foo), 3)[0] == "lazy");
---
*/
enum getParameterStorageClasses = "getParameterStorageClasses";

/**
$(P The argument is a type.
The result is an array of $(D size_t) describing the memory used by an instance of the given type.
)
$(P The first element of the array is the size of the type (for classes it is
the $(GBLINK classInstanceSize)).)
$(P The following elements describe the locations of GC managed pointers within the
memory occupied by an instance of the type.
For type T, there are $(D T.sizeof / size_t.sizeof) possible pointers represented
by the bits of the array values.)
$(P This array can be used by a precise GC to avoid false pointers.)
---
class C
{
    // implicit virtual function table pointer not marked
    // implicit monitor field not marked, usually managed manually
    C next;
    size_t sz;
    void* p;
    void function () fn; // not a GC managed pointer
}

struct S
{
    size_t val1;
    void* p;
    C c;
    byte[] arr;          // { length, ptr }
    void delegate () dg; // { context, func }
}

static assert (__traits(getPointerBitmap, C) == [6*size_t.sizeof, 0b010100]);
static assert (__traits(getPointerBitmap, S) == [7*size_t.sizeof, 0b0110110]);
---
*/
enum getPointerBitmap = "getPointerBitmap";


/**
The argument is a symbol.
The result is a string giving its protection level: "public", "private", "protected", "export", or "package".

---
import std.stdio;

class D
{
    export void foo() { }
    public int bar;
}

void main()
{
    D d = new D();

    auto i = __traits(getProtection, d.foo);
    writeln(i);

    auto j = __traits(getProtection, d.bar);
    writeln(j);
}
---

    $(P Prints:)

$(CONSOLE
export
public
)
*/
enum getProtection = "getProtection";


/**
The same as $(GLINK getVirtualMethods), except that
final functions that do not override anything are included.
*/
enum getVirtualFunctions = "getVirtualFunctions";

/**
The first argument is a class type or an expression of
class type.
The second argument is a string that matches the name of
one of the functions of that class.
The result is a tuple of the virtual overloads of that function.
It does not include final functions that do not override anything.

---
import std.stdio;

class D
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 2; }
}

void main()
{
    D d = new D();

    foreach (t; __traits(getVirtualMethods, D, "foo"))
        writeln(typeid(typeof(t)));

    alias b = typeof(__traits(getVirtualMethods, D, "foo"));
    foreach (t; b)
        writeln(typeid(t));

    auto i = __traits(getVirtualMethods, d, "foo")[1](1);
    writeln(i);
}
---

    $(P Prints:)

$(CONSOLE
void()
int()
void()
int()
2
)
*/
enum getVirtualMethods = "getVirtualMethods";

/**
Takes one argument, a symbol of an aggregate (e.g. struct/class/module).
The result is a tuple of all the unit test functions of that aggregate.
The functions returned are like normal nested static functions,
$(DDSUBLINK glossary, ctfe, CTFE) will work and
$(DDSUBLINK spec/attribute, uda, UDA's) will be accessible.


$(H4 Note:)


The -unittest flag needs to be passed to the compiler. If the flag
is not passed $(CODE __traits(getUnitTests)) will always return an
empty tuple.

---
module foo;

import core.runtime;
import std.stdio;

struct name { string name; }

class Foo
{
    unittest
    {
        writeln("foo.Foo.unittest");
    }
}

@name("foo") unittest
{
    writeln("foo.unittest");
}

template Tuple (T...)
{
    alias Tuple = T;
}

shared static this()
{
  // Override the default unit test runner to do nothing. After that, "main" will
  // be called.
  Runtime.moduleUnitTester = { return true; };
}

void main()
{
    writeln("start main");

    alias tests = Tuple!(__traits(getUnitTests, foo));
    static assert(tests.length == 1);

    alias attributes = Tuple!(__traits(getAttributes, tests[0]));
    static assert(attributes.length == 1);

    foreach (test; tests)
        test();

    foreach (test; __traits(getUnitTests, Foo))
        test();
}
---

    $(P By default, the above will print:)

$(CONSOLE
start main
foo.unittest
foo.Foo.unittest
)
*/
enum getUnitTests = "getUnitTests";

/**
Takes a single argument which must evaluate to a symbol.
The result is the symbol that is the parent of it.
*/
enum parent = "parent";

/**
Takes a single argument, which must evaluate to either
a class type or an expression of class type.
The result
is of type $(CODE size_t), and the value is the number of
bytes in the runtime instance of the class type.
It is based on the static type of a class, not the
polymorphic type.
*/
enum classInstanceSize = "classInstanceSize";

/**
Takes a single argument which must evaluate to a function.
The result is a $(CODE ptrdiff_t) containing the index
of that function within the vtable of the parent type.
If the function passed in is final and does not override
a virtual function, $(D -1) is returned instead.
*/
enum getVirtualIndex = "getVirtualIndex";

/**
Takes a single argument, which must evaluate to either
a type or an expression of type.
A tuple of string literals is returned, each of which
is the name of a member of that type combined with all
of the members of the base classes (if the type is a class).
No name is repeated.
Builtin properties are not included.

---
import std.stdio;

class D
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 0; }
}

void main()
{
    auto b = [ __traits(allMembers, D) ];
    writeln(b);
    // ["__ctor", "__dtor", "foo", "toString", "toHash", "opCmp", "opEquals", "Monitor", "factory"]
}
---

The order in which the strings appear in the result
is not defined.
*/
enum allMembers = "allMembers";

/**
Takes a single argument, which must evaluate to either
a type or an expression of type.
A tuple of string literals is returned, each of which
is the name of a member of that type.
No name is repeated.
Base class member names are not included.
Builtin properties are not included.

---
import std.stdio;

class D
{
    this() { }
    ~this() { }
    void foo() { }
    int foo(int) { return 0; }
}

void main()
{
    auto a = [__traits(derivedMembers, D)];
    writeln(a);    // ["__ctor", "__dtor", "foo"]
}
---

The order in which the strings appear in the result
is not defined.
*/
enum derivedMembers = "derivedMembers";

/**
Takes two arguments and returns bool $(D true) if they
are the same symbol, $(D false) if not.

---
import std.stdio;

struct S { }

int foo();
int bar();

void main()
{
    writeln(__traits(isSame, foo, foo)); // true
    writeln(__traits(isSame, foo, bar)); // false
    writeln(__traits(isSame, foo, S));   // false
    writeln(__traits(isSame, S, S));     // true
    writeln(__traits(isSame, std, S));   // false
    writeln(__traits(isSame, std, std)); // true
}
---

If the two arguments are expressions made up of literals
or enums that evaluate to the same value, true is returned.
*/
enum isSame = "isSame";

/**
Returns a bool $(D true) if all of the arguments
compile (are semantically correct).
The arguments can be symbols, types, or expressions that
are syntactically correct.
The arguments cannot be statements or declarations.


If there are no arguments, the result is $(D false).

---
import std.stdio;

struct S
{
    static int s1;
    int s2;
}

int foo();
int bar();

void main()
{
    writeln(__traits(compiles));                      // false
    writeln(__traits(compiles, foo));                 // true
    writeln(__traits(compiles, foo + 1));             // true
    writeln(__traits(compiles, &foo + 1));            // false
    writeln(__traits(compiles, typeof(1)));           // true
    writeln(__traits(compiles, S.s1));                // true
    writeln(__traits(compiles, S.s3));                // false
    writeln(__traits(compiles, 1,2,3,int,long,std));  // true
    writeln(__traits(compiles, 3[1]));                // false
    writeln(__traits(compiles, 1,2,3,int,long,3[1])); // false
}
---

This is useful for:

$(UL
    $(LI Giving better error messages inside generic code than
    the sometimes hard to follow compiler ones.)
    $(LI Doing a finer grained specialization than template
    partial specialization allows for.)
)
*/
enum compiles = "compiles";

shared static this()
{
    static immutable string[] names =
    [
        isAbstractClass,
        isArithmetic,
        isAssociativeArray,
        isDeprecated,
        isDisabled,
        isFuture,
        isFinalClass,
        isPOD,
        isNested,
        isFloating,
        isIntegral,
        isScalar,
        isStaticArray,
        isUnsigned,
        isVirtualFunction,
        isVirtualMethod,
        isAbstractFunction,
        isFinalFunction,
        isOverrideFunction,
        isStaticFunction,
        isRef,
        isOut,
        isLazy,
        isReturnOnStack,
        hasMember,
        identifier,
        getProtection,
        parent,
        getLinkage,
        getMember,
        getOverloads,
        getVirtualFunctions,
        getVirtualMethods,
        classInstanceSize,
        allMembers,
        derivedMembers,
        isSame,
        compiles,
        getAliasThis,
        getAttributes,
        getFunctionAttributes,
        getFunctionVariadicStyle,
        getParameterStorageClasses,
        getUnitTests,
        getVirtualIndex,
        getPointerBitmap,
    ];

    traitsStringTable._init(40);

    foreach (s; names)
    {
        auto sv = traitsStringTable.insert(s.ptr, s.length, cast(void*)s.ptr);
        assert(sv);
    }
}

/**
 * get an array of size_t values that indicate possible pointer words in memory
 *  if interpreted as the type given as argument
 * Returns: the size of the type in bytes, d_uns64.max on error
 */
extern (C++) d_uns64 getTypePointerBitmap(Loc loc, Type t, Array!(d_uns64)* data)
{
    d_uns64 sz;
    if (t.ty == Tclass && !(cast(TypeClass)t).sym.isInterfaceDeclaration())
        sz = (cast(TypeClass)t).sym.AggregateDeclaration.size(loc);
    else
        sz = t.size(loc);
    if (sz == SIZE_INVALID)
        return d_uns64.max;

    const sz_size_t = Type.tsize_t.size(loc);
    if (sz > sz.max - sz_size_t)
    {
        error(loc, "size overflow for type `%s`", t.toChars());
        return d_uns64.max;
    }

    d_uns64 bitsPerWord = sz_size_t * 8;
    d_uns64 cntptr = (sz + sz_size_t - 1) / sz_size_t;
    d_uns64 cntdata = (cntptr + bitsPerWord - 1) / bitsPerWord;

    data.setDim(cast(size_t)cntdata);
    data.zero();

    extern (C++) final class PointerBitmapVisitor : Visitor
    {
        alias visit = Visitor.visit;
    public:
        extern (D) this(Array!(d_uns64)* _data, d_uns64 _sz_size_t)
        {
            this.data = _data;
            this.sz_size_t = _sz_size_t;
        }

        void setpointer(d_uns64 off)
        {
            d_uns64 ptroff = off / sz_size_t;
            (*data)[cast(size_t)(ptroff / (8 * sz_size_t))] |= 1L << (ptroff % (8 * sz_size_t));
        }

        override void visit(Type t)
        {
            Type tb = t.toBasetype();
            if (tb != t)
                tb.accept(this);
        }

        override void visit(TypeError t)
        {
            visit(cast(Type)t);
        }

        override void visit(TypeNext t)
        {
            assert(0);
        }

        override void visit(TypeBasic t)
        {
            if (t.ty == Tvoid)
                setpointer(offset);
        }

        override void visit(TypeVector t)
        {
        }

        override void visit(TypeArray t)
        {
            assert(0);
        }

        override void visit(TypeSArray t)
        {
            d_uns64 arrayoff = offset;
            d_uns64 nextsize = t.next.size();
            if (nextsize == SIZE_INVALID)
                error = true;
            d_uns64 dim = t.dim.toInteger();
            for (d_uns64 i = 0; i < dim; i++)
            {
                offset = arrayoff + i * nextsize;
                t.next.accept(this);
            }
            offset = arrayoff;
        }

        override void visit(TypeDArray t)
        {
            setpointer(offset + sz_size_t);
        }

        // dynamic array is {length,ptr}
        override void visit(TypeAArray t)
        {
            setpointer(offset);
        }

        override void visit(TypePointer t)
        {
            if (t.nextOf().ty != Tfunction) // don't mark function pointers
                setpointer(offset);
        }

        override void visit(TypeReference t)
        {
            setpointer(offset);
        }

        override void visit(TypeClass t)
        {
            setpointer(offset);
        }

        override void visit(TypeFunction t)
        {
        }

        override void visit(TypeDelegate t)
        {
            setpointer(offset);
        }

        // delegate is {context, function}
        override void visit(TypeQualified t)
        {
            assert(0);
        }

        // assume resolved
        override void visit(TypeIdentifier t)
        {
            assert(0);
        }

        override void visit(TypeInstance t)
        {
            assert(0);
        }

        override void visit(TypeTypeof t)
        {
            assert(0);
        }

        override void visit(TypeReturn t)
        {
            assert(0);
        }

        override void visit(TypeEnum t)
        {
            visit(cast(Type)t);
        }

        override void visit(TypeTuple t)
        {
            visit(cast(Type)t);
        }

        override void visit(TypeSlice t)
        {
            assert(0);
        }

        override void visit(TypeNull t)
        {
            // always a null pointer
        }

        override void visit(TypeStruct t)
        {
            d_uns64 structoff = offset;
            foreach (v; t.sym.fields)
            {
                offset = structoff + v.offset;
                if (v.type.ty == Tclass)
                    setpointer(offset);
                else
                    v.type.accept(this);
            }
            offset = structoff;
        }

        // a "toplevel" class is treated as an instance, while TypeClass fields are treated as references
        void visitClass(TypeClass t)
        {
            d_uns64 classoff = offset;
            // skip vtable-ptr and monitor
            if (t.sym.baseClass)
                visitClass(cast(TypeClass)t.sym.baseClass.type);
            foreach (v; t.sym.fields)
            {
                offset = classoff + v.offset;
                v.type.accept(this);
            }
            offset = classoff;
        }

        Array!(d_uns64)* data;
        d_uns64 offset;
        d_uns64 sz_size_t;
        bool error;
    }

    scope PointerBitmapVisitor pbv = new PointerBitmapVisitor(data, sz_size_t);
    if (t.ty == Tclass)
        pbv.visitClass(cast(TypeClass)t);
    else
        t.accept(pbv);
    return pbv.error ? d_uns64.max : sz;
}

/**
 * get an array of size_t values that indicate possible pointer words in memory
 *  if interpreted as the type given as argument
 * the first array element is the size of the type for independent interpretation
 *  of the array
 * following elements bits represent one word (4/8 bytes depending on the target
 *  architecture). If set the corresponding memory might contain a pointer/reference.
 *
 *  Returns: [T.sizeof, pointerbit0-31/63, pointerbit32/64-63/128, ...]
 */
extern (C++) Expression pointerBitmap(TraitsExp e)
{
    if (!e.args || e.args.dim != 1)
    {
        error(e.loc, "a single type expected for trait pointerBitmap");
        return new ErrorExp();
    }

    Type t = getType((*e.args)[0]);
    if (!t)
    {
        error(e.loc, "`%s` is not a type", (*e.args)[0].toChars());
        return new ErrorExp();
    }

    Array!(d_uns64) data;
    d_uns64 sz = getTypePointerBitmap(e.loc, t, &data);
    if (sz == d_uns64.max)
        return new ErrorExp();

    auto exps = new Expressions();
    exps.push(new IntegerExp(e.loc, sz, Type.tsize_t));
    foreach (d_uns64 i; 0 .. data.dim)
        exps.push(new IntegerExp(e.loc, data[cast(size_t)i], Type.tsize_t));

    auto ale = new ArrayLiteralExp(e.loc, exps);
    ale.type = Type.tsize_t.sarrayOf(data.dim + 1);
    return ale;
}

extern (C++) Expression semanticTraits(TraitsExp e, Scope* sc)
{
    static if (LOGSEMANTIC)
    {
        printf("TraitsExp::semantic() %s\n", e.toChars());
    }

    if (e.ident != Id.compiles &&
        e.ident != Id.isSame &&
        e.ident != Id.identifier &&
        e.ident != Id.getProtection)
    {
        if (!TemplateInstance.semanticTiargs(e.loc, sc, e.args, 1))
            return new ErrorExp();
    }
    size_t dim = e.args ? e.args.dim : 0;

    Expression dimError(int expected)
    {
        e.error("expected %d arguments for `%s` but had %d", expected, e.ident.toChars(), cast(int)dim);
        return new ErrorExp();
    }

    IntegerExp True()
    {
        return new IntegerExp(e.loc, true, Type.tbool);
    }

    IntegerExp False()
    {
        return new IntegerExp(e.loc, false, Type.tbool);
    }

    /********
     * Gets the function type from a given AST node
     * if the node is a function of some sort.
     * Params:
     *   o = an AST node to check for a `TypeFunction`
     *   fdp = if `o` is a FuncDeclaration then fdp is set to that, otherwise `null`
     * Returns:
     *   a type node if `o` is a declaration of
     *   a delegate, function, function-pointer or a variable of the former.
     *   Otherwise, `null`.
     */
    static TypeFunction toTypeFunction(RootObject o, out FuncDeclaration fdp)
    {
        Type t;
        if (auto s = getDsymbolWithoutExpCtx(o))
        {
            if (auto fd = s.isFuncDeclaration())
            {
                t = fd.type;
                fdp = fd;
            }
            else if (auto vd = s.isVarDeclaration())
                t = vd.type;
            else
                t = isType(o);
        }
        else
            t = isType(o);

        if (t)
        {
            if (t.ty == Tfunction)
                return cast(TypeFunction)t;
            else if (t.ty == Tdelegate)
                return cast(TypeFunction)t.nextOf();
            else if (t.ty == Tpointer && t.nextOf().ty == Tfunction)
                return cast(TypeFunction)t.nextOf();
        }

        return null;
    }

    IntegerExp isX(T)(bool function(T) fp)
    {
        if (!dim)
            return False();
        foreach (o; *e.args)
        {
            static if (is(T == Type))
                auto y = getType(o);

            static if (is(T : Dsymbol))
            {
                auto s = getDsymbolWithoutExpCtx(o);
                if (!s)
                    return False();
            }
            static if (is(T == Dsymbol))
                alias y = s;
            static if (is(T == Declaration))
                auto y = s.isDeclaration();
            static if (is(T == FuncDeclaration))
                auto y = s.isFuncDeclaration();

            if (!y || !fp(y))
                return False();
        }
        return True();
    }

    alias isTypeX = isX!Type;
    alias isDsymX = isX!Dsymbol;
    alias isDeclX = isX!Declaration;
    alias isFuncX = isX!FuncDeclaration;

    if (e.ident == Id.isArithmetic)
    {
        return isTypeX(t => t.isintegral() || t.isfloating());
    }
    if (e.ident == Id.isFloating)
    {
        return isTypeX(t => t.isfloating());
    }
    if (e.ident == Id.isIntegral)
    {
        return isTypeX(t => t.isintegral());
    }
    if (e.ident == Id.isScalar)
    {
        return isTypeX(t => t.isscalar());
    }
    if (e.ident == Id.isUnsigned)
    {
        return isTypeX(t => t.isunsigned());
    }
    if (e.ident == Id.isAssociativeArray)
    {
        return isTypeX(t => t.toBasetype().ty == Taarray);
    }
    if (e.ident == Id.isDeprecated)
    {
        if (global.params.vcomplex)
        {
            if (isTypeX(t => t.iscomplex() || t.isimaginary()).isBool(true))
                return True();
        }
        return isDsymX(t => t.isDeprecated());
    }
    if (e.ident == Id.isFuture)
    {
       return isDeclX(t => t.isFuture());
    }
    if (e.ident == Id.isStaticArray)
    {
        return isTypeX(t => t.toBasetype().ty == Tsarray);
    }
    if (e.ident == Id.isAbstractClass)
    {
        return isTypeX(t => t.toBasetype().ty == Tclass &&
                            (cast(TypeClass)t.toBasetype()).sym.isAbstract());
    }
    if (e.ident == Id.isFinalClass)
    {
        return isTypeX(t => t.toBasetype().ty == Tclass &&
                            ((cast(TypeClass)t.toBasetype()).sym.storage_class & STC.final_) != 0);
    }
    if (e.ident == Id.isTemplate)
    {
        if (dim != 1)
            return dimError(1);

        return isDsymX((s)
        {
            if (!s.toAlias().isOverloadable())
                return false;
            return overloadApply(s,
                sm => sm.isTemplateDeclaration() !is null) != 0;
        });
    }
    if (e.ident == Id.isPOD)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto t = isType(o);
        if (!t)
        {
            e.error("type expected as second argument of __traits `%s` instead of `%s`",
                e.ident.toChars(), o.toChars());
            return new ErrorExp();
        }

        Type tb = t.baseElemOf();
        if (auto sd = tb.ty == Tstruct ? (cast(TypeStruct)tb).sym : null)
        {
            return sd.isPOD() ? True() : False();
        }
        return True();
    }
    if (e.ident == Id.isNested)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbolWithoutExpCtx(o);
        if (!s)
        {
        }
        else if (auto ad = s.isAggregateDeclaration())
        {
            return ad.isNested() ? True() : False();
        }
        else if (auto fd = s.isFuncDeclaration())
        {
            return fd.isNested() ? True() : False();
        }

        e.error("aggregate or function expected instead of `%s`", o.toChars());
        return new ErrorExp();
    }
    if (e.ident == Id.isDisabled)
    {
        if (dim != 1)
            return dimError(1);

        return isFuncX(f => f.isDisabled());
    }
    if (e.ident == Id.isAbstractFunction)
    {
        if (dim != 1)
            return dimError(1);

        return isFuncX(f => f.isAbstract());
    }
    if (e.ident == Id.isVirtualFunction)
    {
        if (dim != 1)
            return dimError(1);

        return isFuncX(f => f.isVirtual());
    }
    if (e.ident == Id.isVirtualMethod)
    {
        if (dim != 1)
            return dimError(1);

        return isFuncX(f => f.isVirtualMethod());
    }
    if (e.ident == Id.isFinalFunction)
    {
        if (dim != 1)
            return dimError(1);

        return isFuncX(f => f.isFinalFunc());
    }
    if (e.ident == Id.isOverrideFunction)
    {
        if (dim != 1)
            return dimError(1);

        return isFuncX(f => f.isOverride());
    }
    if (e.ident == Id.isStaticFunction)
    {
        if (dim != 1)
            return dimError(1);

        return isFuncX(f => !f.needThis() && !f.isNested());
    }
    if (e.ident == Id.isRef)
    {
        if (dim != 1)
            return dimError(1);

        return isDeclX(d => d.isRef());
    }
    if (e.ident == Id.isOut)
    {
        if (dim != 1)
            return dimError(1);

        return isDeclX(d => d.isOut());
    }
    if (e.ident == Id.isLazy)
    {
        if (dim != 1)
            return dimError(1);

        return isDeclX(d => (d.storage_class & STC.lazy_) != 0);
    }
    if (e.ident == Id.identifier)
    {
        // Get identifier for symbol as a string literal
        /* Specify 0 for bit 0 of the flags argument to semanticTiargs() so that
         * a symbol should not be folded to a constant.
         * Bit 1 means don't convert Parameter to Type if Parameter has an identifier
         */
        if (!TemplateInstance.semanticTiargs(e.loc, sc, e.args, 2))
            return new ErrorExp();
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        Identifier id;
        if (auto po = isParameter(o))
        {
            id = po.ident;
            assert(id);
        }
        else
        {
            Dsymbol s = getDsymbolWithoutExpCtx(o);
            if (!s || !s.ident)
            {
                e.error("argument `%s` has no identifier", o.toChars());
                return new ErrorExp();
            }
            id = s.ident;
        }

        auto se = new StringExp(e.loc, cast(char*)id.toChars());
        return se.expressionSemantic(sc);
    }
    if (e.ident == Id.getProtection)
    {
        if (dim != 1)
            return dimError(1);

        Scope* sc2 = sc.push();
        sc2.flags = sc.flags | SCOPE.noaccesscheck;
        bool ok = TemplateInstance.semanticTiargs(e.loc, sc2, e.args, 1);
        sc2.pop();
        if (!ok)
            return new ErrorExp();

        auto o = (*e.args)[0];
        auto s = getDsymbolWithoutExpCtx(o);
        if (!s)
        {
            if (!isError(o))
                e.error("argument `%s` has no protection", o.toChars());
            return new ErrorExp();
        }
        if (s.semanticRun == PASS.init)
            s.dsymbolSemantic(null);

        auto protName = protectionToChars(s.prot().kind); // TODO: How about package(names)
        assert(protName);
        auto se = new StringExp(e.loc, cast(char*)protName);
        return se.expressionSemantic(sc);
    }
    if (e.ident == Id.parent)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbolWithoutExpCtx(o);
        if (s)
        {
            // https://issues.dlang.org/show_bug.cgi?id=12496
            // Consider:
            // class T1
            // {
            //     class C(uint value) { }
            // }
            // __traits(parent, T1.C!2)
            if (auto ad = s.isAggregateDeclaration())  // `s` is `C`
            {
                if (ad.isNested())                     // `C` is nested
                {
                    if (auto p = s.toParent())         // `C`'s parent is `C!2`, believe it or not
                    {
                        if (p.isTemplateInstance())    // `C!2` is a template instance
                            s = p;                     // `C!2`'s parent is `T1`
                    }
                }
            }

            if (auto fd = s.isFuncDeclaration()) // https://issues.dlang.org/show_bug.cgi?id=8943
                s = fd.toAliasFunc();
            if (!s.isImport()) // https://issues.dlang.org/show_bug.cgi?id=8922
                s = s.toParent();
        }
        if (!s || s.isImport())
        {
            e.error("argument `%s` has no parent", o.toChars());
            return new ErrorExp();
        }

        if (auto f = s.isFuncDeclaration())
        {
            if (auto td = getFuncTemplateDecl(f))
            {
                if (td.overroot) // if not start of overloaded list of TemplateDeclaration's
                    td = td.overroot; // then get the start
                Expression ex = new TemplateExp(e.loc, td, f);
                ex = ex.expressionSemantic(sc);
                return ex;
            }
            if (auto fld = f.isFuncLiteralDeclaration())
            {
                // Directly translate to VarExp instead of FuncExp
                Expression ex = new VarExp(e.loc, fld, true);
                return ex.expressionSemantic(sc);
            }
        }
        return resolve(e.loc, sc, s, false);
    }
    if (e.ident == Id.hasMember ||
        e.ident == Id.getMember ||
        e.ident == Id.getOverloads ||
        e.ident == Id.getVirtualMethods ||
        e.ident == Id.getVirtualFunctions)
    {
        if (dim != 2 && !(dim == 3 && e.ident == Id.getOverloads))
            return dimError(2);

        auto o = (*e.args)[0];
        auto ex = isExpression((*e.args)[1]);
        if (!ex)
        {
            e.error("expression expected as second argument of __traits `%s`", e.ident.toChars());
            return new ErrorExp();
        }
        ex = ex.ctfeInterpret();

        bool includeTemplates = false;
        if (dim == 3 && e.ident == Id.getOverloads)
        {
            auto b = isExpression((*e.args)[2]);
            b = b.ctfeInterpret();
            if (!b.type.equals(Type.tbool))
            {
                e.error("`bool` expected as third argument of `__traits(getOverloads)`, not `%s` of type `%s`", b.toChars(), b.type.toChars());
                return new ErrorExp();
            }
            includeTemplates = b.isBool(true);
        }

        StringExp se = ex.toStringExp();
        if (!se || se.len == 0)
        {
            e.error("string expected as second argument of __traits `%s` instead of `%s`", e.ident.toChars(), ex.toChars());
            return new ErrorExp();
        }
        se = se.toUTF8(sc);

        if (se.sz != 1)
        {
            e.error("string must be chars");
            return new ErrorExp();
        }
        auto id = Identifier.idPool(se.peekSlice());

        /* Prefer dsymbol, because it might need some runtime contexts.
         */
        Dsymbol sym = getDsymbol(o);
        if (sym)
        {
            if (e.ident == Id.hasMember)
            {
                if (auto sm = sym.search(e.loc, id))
                    return True();
            }
            ex = new DsymbolExp(e.loc, sym);
            ex = new DotIdExp(e.loc, ex, id);
        }
        else if (auto t = isType(o))
            ex = typeDotIdExp(e.loc, t, id);
        else if (auto ex2 = isExpression(o))
            ex = new DotIdExp(e.loc, ex2, id);
        else
        {
            e.error("invalid first argument");
            return new ErrorExp();
        }

        // ignore symbol visibility for these traits, should disable access checks as well
        Scope* scx = sc.push();
        scx.flags |= SCOPE.ignoresymbolvisibility;
        scope (exit) scx.pop();

        if (e.ident == Id.hasMember)
        {
            /* Take any errors as meaning it wasn't found
             */
            ex = ex.trySemantic(scx);
            return ex ? True() : False();
        }
        else if (e.ident == Id.getMember)
        {
            if (ex.op == TOK.dotIdentifier)
                // Prevent semantic() from replacing Symbol with its initializer
                (cast(DotIdExp)ex).wantsym = true;
            ex = ex.expressionSemantic(scx);
            return ex;
        }
        else if (e.ident == Id.getVirtualFunctions ||
                 e.ident == Id.getVirtualMethods ||
                 e.ident == Id.getOverloads)
        {
            uint errors = global.errors;
            Expression eorig = ex;
            ex = ex.expressionSemantic(scx);
            if (errors < global.errors)
                e.error("`%s` cannot be resolved", eorig.toChars());
            //ex.print();

            /* Create tuple of functions of ex
             */
            auto exps = new Expressions();
            Dsymbol f;
            if (ex.op == TOK.variable)
            {
                VarExp ve = cast(VarExp)ex;
                f = ve.var.isFuncDeclaration();
                ex = null;
            }
            else if (ex.op == TOK.dotVariable)
            {
                DotVarExp dve = cast(DotVarExp)ex;
                f = dve.var.isFuncDeclaration();
                if (dve.e1.op == TOK.dotType || dve.e1.op == TOK.this_)
                    ex = null;
                else
                    ex = dve.e1;
            }
            else if (ex.op == TOK.template_)
            {
                VarExp ve = cast(VarExp)ex;
                auto td = ve.var.isTemplateDeclaration();
                f = td;
                if (td && td.funcroot)
                    f = td.funcroot;
                ex = null;
            }

            bool[string] funcTypeHash;

            /* Compute the function signature and insert it in the
             * hashtable, if not present. This is needed so that
             * traits(getOverlods, F3, "visit") does not count `int visit(int)`
             * twice in the following example:
             *
             * =============================================
             * interface F1 { int visit(int);}
             * interface F2 { int visit(int); void visit(); }
             * interface F3 : F2, F1 {}
             *==============================================
             */
            void insertInterfaceInheritedFunction(FuncDeclaration fd, Expression e)
            {
                auto funcType = fd.type.toChars();
                auto len = strlen(funcType);
                string signature = funcType[0 .. len].idup;
                //printf("%s - %s\n", fd.toChars, signature);
                if (signature !in funcTypeHash)
                {
                    funcTypeHash[signature] = true;
                    exps.push(e);
                }
            }

            int dg(Dsymbol s)
            {
                if (includeTemplates)
                {
                    exps.push(new DsymbolExp(Loc.initial, s, false));
                    return 0;
                }
                auto fd = s.isFuncDeclaration();
                if (!fd)
                    return 0;
                if (e.ident == Id.getVirtualFunctions && !fd.isVirtual())
                    return 0;
                if (e.ident == Id.getVirtualMethods && !fd.isVirtualMethod())
                    return 0;

                auto fa = new FuncAliasDeclaration(fd.ident, fd, false);
                fa.protection = fd.protection;

                auto e = ex ? new DotVarExp(Loc.initial, ex, fa, false)
                            : new DsymbolExp(Loc.initial, fa, false);

                // if the parent is an interface declaration
                // we must check for functions with the same signature
                // in different inherited interfaces
                if (sym.isInterfaceDeclaration())
                    insertInterfaceInheritedFunction(fd, e);
                else
                    exps.push(e);
                return 0;
            }

            InterfaceDeclaration ifd = null;
            if (sym)
                ifd = sym.isInterfaceDeclaration();
            // If the symbol passed as a parameter is an
            // interface that inherits other interfaces
            if (ifd && ifd.interfaces)
            {
                // check the overloads of each inherited interface individually
                foreach (bc; ifd.interfaces)
                {
                    if (auto fd = bc.sym.search(e.loc, f.ident))
                        overloadApply(fd, &dg);
                }
            }
            else
                overloadApply(f, &dg);

            auto tup = new TupleExp(e.loc, exps);
            return tup.expressionSemantic(scx);
        }
        else
            assert(0);
    }
    if (e.ident == Id.classInstanceSize)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        auto cd = s ? s.isClassDeclaration() : null;
        if (!cd)
        {
            e.error("first argument is not a class");
            return new ErrorExp();
        }
        if (cd.sizeok != Sizeok.done)
        {
            cd.size(e.loc);
        }
        if (cd.sizeok != Sizeok.done)
        {
            e.error("%s `%s` is forward referenced", cd.kind(), cd.toChars());
            return new ErrorExp();
        }

        return new IntegerExp(e.loc, cd.structsize, Type.tsize_t);
    }
    if (e.ident == Id.getAliasThis)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        auto ad = s ? s.isAggregateDeclaration() : null;
        if (!ad)
        {
            e.error("argument is not an aggregate type");
            return new ErrorExp();
        }

        auto exps = new Expressions();
        if (ad.aliasthis)
            exps.push(new StringExp(e.loc, cast(char*)ad.aliasthis.ident.toChars()));
        Expression ex = new TupleExp(e.loc, exps);
        ex = ex.expressionSemantic(sc);
        return ex;
    }
    if (e.ident == Id.getAttributes)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbolWithoutExpCtx(o);
        if (!s)
        {
            version (none)
            {
                Expression x = isExpression(o);
                Type t = isType(o);
                if (x)
                    printf("e = %s %s\n", Token.toChars(x.op), x.toChars());
                if (t)
                    printf("t = %d %s\n", t.ty, t.toChars());
            }
            e.error("first argument is not a symbol");
            return new ErrorExp();
        }
        if (auto imp = s.isImport())
        {
            s = imp.mod;
        }

        //printf("getAttributes %s, attrs = %p, scope = %p\n", s.toChars(), s.userAttribDecl, s.scope);
        auto udad = s.userAttribDecl;
        auto exps = udad ? udad.getAttributes() : new Expressions();
        auto tup = new TupleExp(e.loc, exps);
        return tup.expressionSemantic(sc);
    }
    if (e.ident == Id.getFunctionAttributes)
    {
        /* Extract all function attributes as a tuple (const/shared/inout/pure/nothrow/etc) except UDAs.
         * https://dlang.org/spec/traits.html#getFunctionAttributes
         */
        if (dim != 1)
            return dimError(1);

        FuncDeclaration fd;
        TypeFunction tf = toTypeFunction((*e.args)[0], fd);

        if (!tf)
        {
            e.error("first argument is not a function");
            return new ErrorExp();
        }

        auto mods = new Expressions();
        PushAttributes pa;
        pa.mods = mods;
        tf.modifiersApply(&pa, &PushAttributes.fp);
        tf.attributesApply(&pa, &PushAttributes.fp, TRUSTformatSystem);

        auto tup = new TupleExp(e.loc, mods);
        return tup.expressionSemantic(sc);
    }
    if (e.ident == Id.isReturnOnStack)
    {
        /* Extract as a boolean if function return value is on the stack
         * https://dlang.org/spec/traits.html#isReturnOnStack
         */
        if (dim != 1)
            return dimError(1);

        RootObject o = (*e.args)[0];
        FuncDeclaration fd;
        TypeFunction tf = toTypeFunction(o, fd);

        if (!tf)
        {
            e.error("argument to `__traits(isReturnOnStack, %s)` is not a function", o.toChars());
            return new ErrorExp();
        }

        bool value = Target.isReturnOnStack(tf);
        return new IntegerExp(e.loc, value, Type.tbool);
    }
    if (e.ident == Id.getFunctionVariadicStyle)
    {
        /* Accept a symbol or a type. Returns one of the following:
         *  "none"      not a variadic function
         *  "argptr"    extern(D) void dstyle(...), use `__argptr` and `__arguments`
         *  "stdarg"    extern(C) void cstyle(int, ...), use core.stdc.stdarg
         *  "typesafe"  void typesafe(T[] ...)
         */
        // get symbol linkage as a string
        if (dim != 1)
            return dimError(1);

        LINK link;
        int varargs;
        auto o = (*e.args)[0];

        FuncDeclaration fd;
        TypeFunction tf = toTypeFunction(o, fd);

        if (tf)
        {
            link = tf.linkage;
            varargs = tf.varargs;
        }
        else
        {
            if (!fd)
            {
                e.error("argument to `__traits(getFunctionVariadicStyle, %s)` is not a function", o.toChars());
                return new ErrorExp();
            }
            link = fd.linkage;
            fd.getParameters(&varargs);
        }
        string style;
        switch (varargs)
        {
            case 0: style = "none";                       break;
            case 1: style = (link == LINK.d) ? "argptr"
                                             : "stdarg";  break;
            case 2:     style = "typesafe";               break;
            default:
                assert(0);
        }
        auto se = new StringExp(e.loc, cast(char*)style);
        return se.expressionSemantic(sc);
    }
    if (e.ident == Id.getParameterStorageClasses)
    {
        /* Accept a function symbol or a type, followed by a parameter index.
         * Returns a tuple of strings of the parameter's storage classes.
         */
        // get symbol linkage as a string
        if (dim != 2)
            return dimError(2);

        auto o = (*e.args)[0];
        auto o1 = (*e.args)[1];

        FuncDeclaration fd;
        TypeFunction tf = toTypeFunction(o, fd);

        Parameters* fparams;
        if (tf)
        {
            fparams = tf.parameters;
        }
        else
        {
            if (!fd)
            {
                e.error("first argument to `__traits(getParameterStorageClasses, %s, %s)` is not a function",
                    o.toChars(), o1.toChars());
                return new ErrorExp();
            }
            fparams = fd.getParameters(null);
        }

        StorageClass stc;

        // Set stc to storage class of the ith parameter
        auto ex = isExpression((*e.args)[1]);
        if (!ex)
        {
            e.error("expression expected as second argument of `__traits(getParameterStorageClasses, %s, %s)`",
                o.toChars(), o1.toChars());
            return new ErrorExp();
        }
        ex = ex.ctfeInterpret();
        auto ii = ex.toUInteger();
        if (ii >= Parameter.dim(fparams))
        {
            e.error("parameter index must be in range 0..%u not %s", cast(uint)Parameter.dim(fparams), ex.toChars());
            return new ErrorExp();
        }

        uint n = cast(uint)ii;
        Parameter p = Parameter.getNth(fparams, n);
        stc = p.storageClass;

        // This mirrors hdrgen.visit(Parameter p)
        if (p.type && p.type.mod & MODFlags.shared_)
            stc &= ~STC.shared_;

        auto exps = new Expressions;

        void push(string s)
        {
            exps.push(new StringExp(e.loc, cast(char*)s.ptr, cast(uint)s.length));
        }

        if (stc & STC.auto_)
            push("auto");
        if (stc & STC.return_)
            push("return");

        if (stc & STC.out_)
            push("out");
        else if (stc & STC.ref_)
            push("ref");
        else if (stc & STC.in_)
            push("in");
        else if (stc & STC.lazy_)
            push("lazy");
        else if (stc & STC.alias_)
            push("alias");

        if (stc & STC.const_)
            push("const");
        if (stc & STC.immutable_)
            push("immutable");
        if (stc & STC.wild)
            push("inout");
        if (stc & STC.shared_)
            push("shared");
        if (stc & STC.scope_ && !(stc & STC.scopeinferred))
            push("scope");

        auto tup = new TupleExp(e.loc, exps);
        return tup.expressionSemantic(sc);
    }
    if (e.ident == Id.getLinkage)
    {
        // get symbol linkage as a string
        if (dim != 1)
            return dimError(1);

        LINK link;
        auto o = (*e.args)[0];

        FuncDeclaration fd;
        TypeFunction tf = toTypeFunction(o, fd);

        if (tf)
            link = tf.linkage;
        else
        {
            auto s = getDsymbol(o);
            Declaration d;
            ClassDeclaration c;
            if (!s || ((d = s.isDeclaration()) is null && (c = s.isClassDeclaration()) is null))
            {
                e.error("argument to `__traits(getLinkage, %s)` is not a declaration", o.toChars());
                return new ErrorExp();
            }
            if (d !is null)
                link = d.linkage;
            else final switch (c.classKind)
            {
                case ClassKind.d:
                    link = LINK.d;
                    break;
                case ClassKind.cpp:
                    link = LINK.cpp;
                    break;
                case ClassKind.objc:
                    link = LINK.objc;
                    break;
            }
        }
        auto linkage = linkageToChars(link);
        auto se = new StringExp(e.loc, cast(char*)linkage);
        return se.expressionSemantic(sc);
    }
    if (e.ident == Id.allMembers ||
        e.ident == Id.derivedMembers)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbol(o);
        if (!s)
        {
            e.error("argument has no members");
            return new ErrorExp();
        }
        if (auto imp = s.isImport())
        {
            // https://issues.dlang.org/show_bug.cgi?id=9692
            s = imp.mod;
        }

        auto sds = s.isScopeDsymbol();
        if (!sds || sds.isTemplateDeclaration())
        {
            e.error("%s `%s` has no members", s.kind(), s.toChars());
            return new ErrorExp();
        }

        auto idents = new Identifiers();

        int pushIdentsDg(size_t n, Dsymbol sm)
        {
            if (!sm)
                return 1;

            // skip local symbols, such as static foreach loop variables
            if (auto decl = sm.isDeclaration())
            {
                if (decl.storage_class & STC.local)
                {
                    return 0;
                }
            }

            //printf("\t[%i] %s %s\n", i, sm.kind(), sm.toChars());
            if (sm.ident)
            {
                const idx = sm.ident.toChars();
                if (idx[0] == '_' &&
                    idx[1] == '_' &&
                    sm.ident != Id.ctor &&
                    sm.ident != Id.dtor &&
                    sm.ident != Id.__xdtor &&
                    sm.ident != Id.postblit &&
                    sm.ident != Id.__xpostblit)
                {
                    return 0;
                }
                if (sm.ident == Id.empty)
                {
                    return 0;
                }
                if (sm.isTypeInfoDeclaration()) // https://issues.dlang.org/show_bug.cgi?id=15177
                    return 0;
                if (!sds.isModule() && sm.isImport()) // https://issues.dlang.org/show_bug.cgi?id=17057
                    return 0;

                //printf("\t%s\n", sm.ident.toChars());

                /* Skip if already present in idents[]
                 */
                foreach (id; *idents)
                {
                    if (id == sm.ident)
                        return 0;

                    // Avoid using strcmp in the first place due to the performance impact in an O(N^2) loop.
                    debug assert(strcmp(id.toChars(), sm.ident.toChars()) != 0);
                }
                idents.push(sm.ident);
            }
            else if (auto ed = sm.isEnumDeclaration())
            {
                ScopeDsymbol._foreach(null, ed.members, &pushIdentsDg);
            }
            return 0;
        }

        ScopeDsymbol._foreach(sc, sds.members, &pushIdentsDg);
        auto cd = sds.isClassDeclaration();
        if (cd && e.ident == Id.allMembers)
        {
            if (cd.semanticRun < PASS.semanticdone)
                cd.dsymbolSemantic(null); // https://issues.dlang.org/show_bug.cgi?id=13668
                                   // Try to resolve forward reference

            void pushBaseMembersDg(ClassDeclaration cd)
            {
                for (size_t i = 0; i < cd.baseclasses.dim; i++)
                {
                    auto cb = (*cd.baseclasses)[i].sym;
                    assert(cb);
                    ScopeDsymbol._foreach(null, cb.members, &pushIdentsDg);
                    if (cb.baseclasses.dim)
                        pushBaseMembersDg(cb);
                }
            }

            pushBaseMembersDg(cd);
        }

        // Turn Identifiers into StringExps reusing the allocated array
        assert(Expressions.sizeof == Identifiers.sizeof);
        auto exps = cast(Expressions*)idents;
        foreach (i, id; *idents)
        {
            auto se = new StringExp(e.loc, cast(char*)id.toChars());
            (*exps)[i] = se;
        }

        /* Making this a tuple is more flexible, as it can be statically unrolled.
         * To make an array literal, enclose __traits in [ ]:
         *   [ __traits(allMembers, ...) ]
         */
        Expression ex = new TupleExp(e.loc, exps);
        ex = ex.expressionSemantic(sc);
        return ex;
    }
    if (e.ident == Id.compiles)
    {
        /* Determine if all the objects - types, expressions, or symbols -
         * compile without error
         */
        if (!dim)
            return False();

        foreach (o; *e.args)
        {
            uint errors = global.startGagging();
            Scope* sc2 = sc.push();
            sc2.tinst = null;
            sc2.minst = null;
            sc2.flags = (sc.flags & ~(SCOPE.ctfe | SCOPE.condition)) | SCOPE.compile | SCOPE.fullinst;

            bool err = false;

            auto t = isType(o);
            auto ex = t ? t.typeToExpression() : isExpression(o);
            if (!ex && t)
            {
                Dsymbol s;
                t.resolve(e.loc, sc2, &ex, &t, &s);
                if (t)
                {
                    t.typeSemantic(e.loc, sc2);
                    if (t.ty == Terror)
                        err = true;
                }
                else if (s && s.errors)
                    err = true;
            }
            if (ex)
            {
                ex = ex.expressionSemantic(sc2);
                ex = resolvePropertiesOnly(sc2, ex);
                ex = ex.optimize(WANTvalue);
                if (sc2.func && sc2.func.type.ty == Tfunction)
                {
                    const tf = cast(TypeFunction)sc2.func.type;
                    err |= tf.isnothrow && canThrow(ex, sc2.func, false);
                }
                ex = checkGC(sc2, ex);
                if (ex.op == TOK.error)
                    err = true;
            }

            // Carefully detach the scope from the parent and throw it away as
            // we only need it to evaluate the expression
            // https://issues.dlang.org/show_bug.cgi?id=15428
            sc2.detach();

            if (global.endGagging(errors) || err)
            {
                return False();
            }
        }
        return True();
    }
    if (e.ident == Id.isSame)
    {
        /* Determine if two symbols are the same
         */
        if (dim != 2)
            return dimError(2);

        if (!TemplateInstance.semanticTiargs(e.loc, sc, e.args, 0))
            return new ErrorExp();


        auto o1 = (*e.args)[0];
        auto o2 = (*e.args)[1];

        static FuncLiteralDeclaration isLambda(RootObject oarg)
        {
            if (auto t = isDsymbol(oarg))
            {
                if (auto td = t.isTemplateDeclaration())
                {
                    if (td.members && td.members.dim == 1)
                    {
                        if (auto fd = (*td.members)[0].isFuncLiteralDeclaration())
                            return fd;
                    }
                }
            }
            else if (auto ea = isExpression(oarg))
            {
                if (ea.op == TOK.function_)
                {
                    if (auto fe = cast(FuncExp)ea)
                        return fe.fd;
                }
            }

            return null;
        }

        auto l1 = isLambda(o1);
        auto l2 = isLambda(o2);

        if (l1 && l2)
        {
            import dmd.lambdacomp : isSameFuncLiteral;
            if (isSameFuncLiteral(l1, l2, sc))
                return True();
        }

        auto s1 = getDsymbol(o1);
        auto s2 = getDsymbol(o2);
        //printf("isSame: %s, %s\n", o1.toChars(), o2.toChars());
        version (none)
        {
            printf("o1: %p\n", o1);
            printf("o2: %p\n", o2);
            if (!s1)
            {
                if (auto ea = isExpression(o1))
                    printf("%s\n", ea.toChars());
                if (auto ta = isType(o1))
                    printf("%s\n", ta.toChars());
                return False();
            }
            else
                printf("%s %s\n", s1.kind(), s1.toChars());
        }
        if (!s1 && !s2)
        {
            auto ea1 = isExpression(o1);
            auto ea2 = isExpression(o2);
            if (ea1 && ea2)
            {
                if (ea1.equals(ea2))
                    return True();
            }
        }
        if (!s1 || !s2)
            return False();

        s1 = s1.toAlias();
        s2 = s2.toAlias();

        if (auto fa1 = s1.isFuncAliasDeclaration())
            s1 = fa1.toAliasFunc();
        if (auto fa2 = s2.isFuncAliasDeclaration())
            s2 = fa2.toAliasFunc();

        // https://issues.dlang.org/show_bug.cgi?id=11259
        // compare import symbol to a package symbol
        static bool cmp(Dsymbol s1, Dsymbol s2)
        {
            auto imp = s1.isImport();
            return imp && imp.pkg && imp.pkg == s2.isPackage();
        }

        if (cmp(s1,s2) || cmp(s2,s1))
            return True();

        return (s1 == s2) ? True() : False();
    }
    if (e.ident == Id.getUnitTests)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbolWithoutExpCtx(o);
        if (!s)
        {
            e.error("argument `%s` to __traits(getUnitTests) must be a module or aggregate",
                o.toChars());
            return new ErrorExp();
        }
        if (auto imp = s.isImport()) // https://issues.dlang.org/show_bug.cgi?id=10990
            s = imp.mod;

        auto sds = s.isScopeDsymbol();
        if (!sds)
        {
            e.error("argument `%s` to __traits(getUnitTests) must be a module or aggregate, not a %s",
                s.toChars(), s.kind());
            return new ErrorExp();
        }

        auto exps = new Expressions();
        if (global.params.useUnitTests)
        {
            bool[void*] uniqueUnitTests;

            void collectUnitTests(Dsymbols* a)
            {
                if (!a)
                    return;
                foreach (s; *a)
                {
                    if (auto atd = s.isAttribDeclaration())
                    {
                        collectUnitTests(atd.include(null));
                        continue;
                    }
                    if (auto ud = s.isUnitTestDeclaration())
                    {
                        if (cast(void*)ud in uniqueUnitTests)
                            continue;

                        auto ad = new FuncAliasDeclaration(ud.ident, ud, false);
                        ad.protection = ud.protection;

                        auto e = new DsymbolExp(Loc.initial, ad, false);
                        exps.push(e);

                        uniqueUnitTests[cast(void*)ud] = true;
                    }
                }
            }

            collectUnitTests(sds.members);
        }
        auto te = new TupleExp(e.loc, exps);
        return te.expressionSemantic(sc);
    }
    if (e.ident == Id.getVirtualIndex)
    {
        if (dim != 1)
            return dimError(1);

        auto o = (*e.args)[0];
        auto s = getDsymbolWithoutExpCtx(o);

        auto fd = s ? s.isFuncDeclaration() : null;
        if (!fd)
        {
            e.error("first argument to __traits(getVirtualIndex) must be a function");
            return new ErrorExp();
        }

        fd = fd.toAliasFunc(); // Necessary to support multiple overloads.
        return new IntegerExp(e.loc, fd.vtblIndex, Type.tptrdiff_t);
    }
    if (e.ident == Id.getPointerBitmap)
    {
        return pointerBitmap(e);
    }

    extern (D) void* trait_search_fp(const(char)* seed, ref int cost)
    {
        //printf("trait_search_fp('%s')\n", seed);
        size_t len = strlen(seed);
        if (!len)
            return null;
        cost = 0;
        StringValue* sv = traitsStringTable.lookup(seed, len);
        return sv ? sv.ptrvalue : null;
    }

    if (auto sub = cast(const(char)*)speller(e.ident.toChars(), &trait_search_fp, idchars))
        e.error("unrecognized trait `%s`, did you mean `%s`?", e.ident.toChars(), sub);
    else
        e.error("unrecognized trait `%s`", e.ident.toChars());
    return new ErrorExp();
}
