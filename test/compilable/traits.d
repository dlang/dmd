// REQUIRED_ARGS:
// EXTRA_FILES: imports/plainpackage/plainmodule.d imports/pkgmodule/package.d imports/pkgmodule/plainmodule.d

// This file is intended to contain all compilable traits-related tests in an
// effort to keep the number of files in the `compilable` folder to a minimum.

module traits;

static assert(is(typeof(__traits(getTargetInfo, "cppRuntimeLibrary")) == string));

version (CppRuntime_Microsoft)
{
    static assert(__traits(getTargetInfo, "cppRuntimeLibrary") == "libcmt");
}

import imports.plainpackage.plainmodule;
import imports.pkgmodule.plainmodule;

#line 40
struct MyStruct;

alias a = imports.plainpackage;
alias b = imports.pkgmodule.plainmodule;

static assert(__traits(isPackage, imports.plainpackage));
static assert(__traits(isPackage, a));
static assert(!__traits(isPackage, imports.plainpackage.plainmodule));
static assert(!__traits(isPackage, b));
static assert(__traits(isPackage, imports.pkgmodule));
static assert(!__traits(isPackage, MyStruct));

static assert(!__traits(isModule, imports.plainpackage));
static assert(!__traits(isModule, a));
static assert(__traits(isModule, imports.plainpackage.plainmodule));
static assert(__traits(isModule, b));
// This is supposed to work even though we haven't directly imported imports.pkgmodule.
static assert(__traits(isModule, imports.pkgmodule));
static assert(!__traits(isModule, MyStruct));

/******************************************/
// https://issues.dlang.org/show_bug.cgi?id=19942

static assert(!__traits(compiles, { a.init; }));
static assert(!__traits(compiles, { import m : a; a.init; }));

version(Windows)
    static assert(__traits(getLocation, MyStruct)[0] == `compilable\traits.d`);
else
    static assert(__traits(getLocation, MyStruct)[0] == "compilable/traits.d");
static assert(__traits(getLocation, MyStruct)[1] == 39);
static assert(__traits(getLocation, MyStruct)[2] == 1);

int foo();
int foo(int);

static assert(__traits(getLocation, __traits(getOverloads, traits, "foo")[1])[1] == 73);

mixin("int bar;");
static assert(__traits(getLocation, bar)[1] == 77);

struct Outer
{
    struct Nested{}

    void method() {}
}
static assert(__traits(getLocation, Outer.Nested)[1] == 82);
static assert(__traits(getLocation, Outer.method)[1] == 84);

