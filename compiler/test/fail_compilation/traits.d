/************************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/traits.d(98): Error: `getTargetInfo` key `"not_a_target_info"` not supported by this implementation
enum A1 = __traits(getTargetInfo, "not_a_target_info");
          ^
fail_compilation/traits.d(99): Error: string expected as argument of __traits `getTargetInfo` instead of `100`
enum B1 = __traits(getTargetInfo, 100);
          ^
fail_compilation/traits.d(100): Error: expected 1 arguments for `getTargetInfo` but had 2
enum C1 = __traits(getTargetInfo, "cppRuntimeLibrary", "bits");
          ^
fail_compilation/traits.d(101): Error: expected 1 arguments for `getTargetInfo` but had 0
enum D1 = __traits(getTargetInfo);
          ^
fail_compilation/traits.d(104): Error: undefined identifier `imports.nonexistent`
enum A2 = __traits(isPackage, imports.nonexistent);
          ^
fail_compilation/traits.d(105): Error: undefined identifier `imports.nonexistent`
enum B2 = __traits(isModule, imports.nonexistent);
          ^
fail_compilation/traits.d(106): Error: expected 1 arguments for `isPackage` but had 0
enum C2 = __traits(isPackage);
          ^
fail_compilation/traits.d(107): Error: expected 1 arguments for `isModule` but had 0
enum D2 = __traits(isModule);
          ^
fail_compilation/traits.d(116): Error: in expression `__traits(allMembers, float)` `float` can't have members
enum AM0 = __traits(allMembers, float);                     // compile error
           ^
fail_compilation/traits.d(116):        `float` must evaluate to either a module, a struct, an union, a class, an interface or a template instantiation
fail_compilation/traits.d(122): Error: in expression `__traits(allMembers, TemplatedStruct)` struct `TemplatedStruct(T)` has no members
enum AM6 = __traits(allMembers, TemplatedStruct);           // compile error
           ^
fail_compilation/traits.d(122):        `TemplatedStruct(T)` must evaluate to either a module, a struct, an union, a class, an interface or a template instantiation
fail_compilation/traits.d(125): Error: in expression `__traits(derivedMembers, float)` `float` can't have members
enum DM0 = __traits(derivedMembers, float);                 // compile error
           ^
fail_compilation/traits.d(125):        `float` must evaluate to either a module, a struct, an union, a class, an interface or a template instantiation
fail_compilation/traits.d(132): Error: in expression `__traits(derivedMembers, TemplatedStruct)` struct `TemplatedStruct(T)` has no members
enum DM7 = __traits(derivedMembers, TemplatedStruct);       // compile error
           ^
fail_compilation/traits.d(132):        `TemplatedStruct(T)` must evaluate to either a module, a struct, an union, a class, an interface or a template instantiation
fail_compilation/traits.d(140): Error: function `traits.func1` circular reference in `__traits(GetCppNamespaces,...)`
extern(C++, __traits(getCppNamespaces, func2)) void func1 () {}
                                                    ^
fail_compilation/traits.d(149): Error: function `traits.foo1.func1` circular reference in `__traits(GetCppNamespaces,...)`
extern(C++, __traits(getCppNamespaces, foobar1.func2)) void func1 () {}
                                                            ^
fail_compilation/traits.d(156): Error: undefined identifier `T`
auto yip(int f) {return T[];}
                        ^
fail_compilation/traits.d(157):        while evaluating `pragma(msg, __traits(getParameterStorageClasses, yip, 0))`
pragma(msg, __traits(getParameterStorageClasses, yip, 0));
^
fail_compilation/traits.d(163): Error: expected 1 arguments for `hasCopyConstructor` but had 0
pragma(msg, __traits(hasCopyConstructor));
            ^
fail_compilation/traits.d(163):        while evaluating `pragma(msg, __traits(hasCopyConstructor))`
pragma(msg, __traits(hasCopyConstructor));
^
fail_compilation/traits.d(164): Error: type expected as second argument of __traits `hasCopyConstructor` instead of `S()`
pragma(msg, __traits(hasCopyConstructor, S()));
            ^
fail_compilation/traits.d(164):        while evaluating `pragma(msg, __traits(hasCopyConstructor, S()))`
pragma(msg, __traits(hasCopyConstructor, S()));
^
fail_compilation/traits.d(165): Error: expected 1 arguments for `hasPostblit` but had 0
pragma(msg, __traits(hasPostblit));
            ^
fail_compilation/traits.d(165):        while evaluating `pragma(msg, __traits(hasPostblit))`
pragma(msg, __traits(hasPostblit));
^
fail_compilation/traits.d(166): Error: type expected as second argument of __traits `hasPostblit` instead of `S()`
pragma(msg, __traits(hasPostblit, S()));
            ^
fail_compilation/traits.d(166):        while evaluating `pragma(msg, __traits(hasPostblit, S()))`
pragma(msg, __traits(hasPostblit, S()));
^
fail_compilation/traits.d(170): Error: alias `traits.a` cannot alias an expression `true`
alias a = __traits(compiles, 1);
^
fail_compilation/traits.d(171): Error: alias `traits.b` cannot alias an expression `false`
alias b = __traits(isIntegral, 1.1);
^
fail_compilation/traits.d(172): Error: alias `traits.c` cannot alias an expression `"Object"`
alias c = __traits(identifier, Object);
^
fail_compilation/traits.d(173):        while evaluating `pragma(msg, a)`
pragma(msg, a, b, c);
^
---
*/

// Line 100 starts here
enum A1 = __traits(getTargetInfo, "not_a_target_info");
enum B1 = __traits(getTargetInfo, 100);
enum C1 = __traits(getTargetInfo, "cppRuntimeLibrary", "bits");
enum D1 = __traits(getTargetInfo);

// Line 200 starts here
enum A2 = __traits(isPackage, imports.nonexistent);
enum B2 = __traits(isModule, imports.nonexistent);
enum C2 = __traits(isPackage);
enum D2 = __traits(isModule);

interface Interface {}
struct TemplatedStruct(T) {}
struct Struct {}
union Union {}
class Class {}

// Line 300 starts here
enum AM0 = __traits(allMembers, float);                     // compile error
enum AM1 = __traits(allMembers, Struct);                    // no error
enum AM2 = __traits(allMembers, Union);                     // no error
enum AM3 = __traits(allMembers, Class);                     // no error
enum AM4 = __traits(allMembers, Interface);                 // no error
enum AM5 = __traits(allMembers, TemplatedStruct!float);     // no error
enum AM6 = __traits(allMembers, TemplatedStruct);           // compile error
enum AM7 = __traits(allMembers, mixin(__MODULE__));         // no error

enum DM0 = __traits(derivedMembers, float);                 // compile error
enum DM1 = __traits(derivedMembers, Struct);                // no error
enum DM2 = __traits(derivedMembers, Struct);                // no error
enum DM3 = __traits(derivedMembers, Union);                 // no error
enum DM4 = __traits(derivedMembers, Class);                 // no error
enum DM5 = __traits(derivedMembers, Interface);             // no error
enum DM6 = __traits(derivedMembers, TemplatedStruct!float); // no error
enum DM7 = __traits(derivedMembers, TemplatedStruct);       // compile error
enum DM8 = __traits(derivedMembers, mixin(__MODULE__));     // no error

// Line 400 starts here
extern(C++, "bar")
extern(C++, __traits(getCppNamespaces, func1)) void func () {}

extern(C++, "foo")
extern(C++, __traits(getCppNamespaces, func2)) void func1 () {}

extern(C++, "foobar")
extern(C++, __traits(getCppNamespaces, func)) void func2 () {}

extern(C++, bar1)
extern(C++, __traits(getCppNamespaces, foo1.func1)) void func () {}

extern(C++, foo1)
extern(C++, __traits(getCppNamespaces, foobar1.func2)) void func1 () {}

extern(C++, foobar1)
extern(C++, __traits(getCppNamespaces, bar1.func)) void func2 () {}

// Line 500 starts here

auto yip(int f) {return T[];}
pragma(msg, __traits(getParameterStorageClasses, yip, 0));


// Line 600 starts here

struct S { this (ref S rhs) {} }
pragma(msg, __traits(hasCopyConstructor));
pragma(msg, __traits(hasCopyConstructor, S()));
pragma(msg, __traits(hasPostblit));
pragma(msg, __traits(hasPostblit, S()));

// Line 700 starts here

alias a = __traits(compiles, 1);
alias b = __traits(isIntegral, 1.1);
alias c = __traits(identifier, Object);
pragma(msg, a, b, c);
