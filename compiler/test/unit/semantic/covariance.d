// Tests regarding Type.covariant
//
// See ../../README.md for information about DMD unit tests.

module semantic.covariance;

import dmd.astenums : STC, StorageClass;
import dmd.func : FuncDeclaration;
import dmd.mtype : Covariant, Type;
import dmd.typesem : covariant;

import support;

@("sanity")
unittest
{
    testCovariant(Type.tvoid, Type.tvoid, Result(Covariant.yes));
    testCovariant(Type.tvoid, Type.tint8, Result(Covariant.distinct));
}

@("empty-params")
unittest
{
    Test test = {
        // Example code denoting the compared function types
        code: q{

            void base();

            void target();
        },

        // Test: typeof(base).covariant(typeof(target))
        baseToTarget: {
            result: Covariant.yes,
        },
    };
    runTest(test);
}

@("param-count")
unittest
{
    Test test = {
        code: q{

            void base();

            void target(int);
        },

        baseToTarget: {
            result: Covariant.distinct,
        },
    };
    runTest(test);
}

@("variadics")
unittest
{
    Test test = {
        code: q{

            int base();

            int target(...);
        },

        baseToTarget: {
            result: Covariant.distinct,
        },
    };
    runTest(test);
}

@("variadics2")
unittest
{
    Test test = {
        code: q{

            int base(...);

            int target(...);
        },

        baseToTarget: {
            result: Covariant.yes,
        },
    };
    runTest(test);
}

@("missmatched-param-types")
unittest
{
    Test test = {
        code: q{

            void base(string);

            void target(int);
        },

        // Test: typeof(base).covariant(typeof(target))
        baseToTarget: {
            result: Covariant.distinct,
        },

        // Reversed test: typeof(target).covariant(typeof(base))
        targetToBase: {
            result: Covariant.distinct
        }
    };
    runTest(test);
}

@("class-params")
unittest
{
    Test test = {
        code: q{

            void base(Throwable);

            void target(const Throwable);
        },

        baseToTarget: {
            result: Covariant.distinct,
        },

        targetToBase: {
            result: Covariant.yes
        }
    };
    runTest(test);
}

@("struct-params")
unittest
{
    Test test = {
        code: q{

            struct S { int* ptr; }

            void base(S);

            void target(const S);
        },

        baseToTarget: {
            result: Covariant.distinct,
        },

        targetToBase: {
            result: Covariant.yes
        }
    };
    runTest(test);
}

@("pointer-params")
unittest
{
    Test test = {
        code: q{

            void base(int*);

            void target(void**);
        },

        baseToTarget: {
            result: Covariant.distinct,
        },

        targetToBase: {
            result: Covariant.distinct
        }
    };
    runTest(test);
}

@("array-params")
unittest
{
    Test test = {
        code: q{
            void base(const int[]);

            void target(int[]);
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.distinct
        }
    };
    runTest(test);
}

@("function-pointer-params")
unittest
{
    Test test = {
        code: q{
            void base(int function() @system);

            void target(int function() @safe);
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.distinct
        }
    };
    runTest(test);
}

@("delegate-params")
unittest
{
    Test test = {
        code: q{
            void base(int delegate() @system);

            void target(int delegate() @safe);
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.distinct,
        }
    };
    runTest(test);
}

@("linkage")
unittest
{
    Test test = {
        code: q{
            void base();

            extern(C++) void target();
        },

        baseToTarget: {
            result: Covariant.no,
        },
    };
    runTest(test);
}

@("class-return")
unittest
{
    Test test = {
        code: q{
            Throwable base();

            const(Throwable) target();
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.no
        }
    };
    runTest(test);
}

@("struct-return")
unittest
{
    Test test = {
        code: q{
            struct S { int* ptr; }

            S base();

            const(S) target();
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.no
        }
    };
    runTest(test);
}

@("pointer-return")
unittest
{
    Test test = {
        code: q{
            int* base();

            void* target();
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.no
        }
    };
    runTest(test);
}

@("null-return")
unittest
{
    Test test = {
        code: q{
            typeof(null) base();

            void* target();
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.no
        }
    };
    runTest(test);
}

@("noreturn-return")
unittest
{
    Test test = {
        code: q{
            noreturn base();

            void* target();
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.no
        }
    };
    runTest(test);
}


@("different-ref-return")
unittest
{
    Test test = {
        code: q{
            ref int base();

            int target();
        },

        baseToTarget: {
            result: Covariant.no,
        },

        targetToBase: {
            result: Covariant.no
        }
    };
    runTest(test);
}

@("different-scope")
unittest
{
    Test test = {
        code: q{
            struct S
            {
                int* ptr; // Force indirections

                S base() scope;

                S target();
            }
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.no
        }
    };
    runTest(test);
}

@("different-return")
unittest
{
    Test test = {
        code: q{
            struct S
            {
                int* ptr; // Force indirections

                S base();

                S target() return;
            }
        },

        baseToTarget: {
            result: Covariant.yes,  // Is this correct?
        },

        targetToBase: {
            result: Covariant.no
        }
    };
    runTest(test);
}

@("scope-vs-return")
unittest
{
    Test test = {
        code: q{
            struct S
            {
                int* ptr; // Force indirections

                S base() scope;

                S target() return;
            }
        },

        baseToTarget: {
            result: Covariant.no,
        },

        targetToBase: {
            result: Covariant.no
        }
    };
    runTest(test);
}

@("return-vs-ref")
unittest
{
    Test test = {
        code: q{
            struct S
            {
                int* ptr; // Force indirections

                ref S base() scope;

                ref S target() return;
            }
        },

        baseToTarget: {
            result: Covariant.yes, // Adding ref to the preceeding test makes them covariant??
        },

        targetToBase: {
            result: Covariant.no
        }
    };
    runTest(test);
}

@("mutability")
unittest
{
    Test test = {
        code: q{
            struct S
            {
                int* ptr; // Force indirections

                void base() const;

                void target();
            }
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.distinct // Should be no?
        }
    };
    runTest(test);
}

@("attributes")
unittest
{
    Test test = {
        code: q{

            void base() pure nothrow @nogc @safe;

            void target();
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.no,
            suggestion: STC.pure_ | STC.nothrow_ | STC.nogc | STC.safe
        }
    };
    runTest(test);
}

@("function-pointer-param-mutability")
unittest
{
    Test test = {
        code: q{
            struct S
            {
                int* ptr; // Force indirections

                void base(const int function()) const;

                void target(int function());
            }
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.distinct // Should be no?
        }
    };
    runTest(test);
}

@("function-pointer-param-mutability-2")
unittest
{
    Test test = {
        code: q{
            struct S
            {
                int* ptr; // Force indirections

                void base(int function()) const;

                void target(const int function());
            }
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.distinct
        }
    };
    runTest(test);
}


@("delegate-param-mutability")
unittest
{
    Test test = {
        code: q{
            struct S
            {
                int* ptr; // Force indirections

                void base(const int delegate()) const;

                void target(int delegate());
            }
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.distinct // Should be no?
        }
    };
    runTest(test);
}

@("delegate-param-mutability-2")
unittest
{
    Test test = {
        code: q{
            struct S
            {
                int* ptr; // Force indirections

                void base(int delegate()) const;

                void target(const int delegate());
            }
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.distinct
        }
    };
    runTest(test);
}

// Deconstructing the failure observed in runnable/xtest46.d
@("xtest46-base")
unittest
{
    Test test = {
        code: q{
             static struct T
            {
                void base(ref int*);
                void target(ref const int*) const;
            }
        },

        baseToTarget: {
            result: Covariant.distinct,
        },

        targetToBase: {
            result: Covariant.yes
        }
    };
    runTest(test);
}

@("xtest46-free-function")
unittest
{
    Test test = {
        code: q{

            void base(void function(ref int*));
            void target(void function(ref const int*));
        },

        baseToTarget: {
            result: Covariant.yes,
        },

        targetToBase: {
            result: Covariant.distinct
        }
    };
    runTest(test);
}

@("xtest46-function")
unittest
{
    Test test = {
        code: q{
            struct T
            {
                void base(void function(ref int*));
                void target(void function(ref const int*)) const;
            }
        },

        baseToTarget: {
            result: Covariant.distinct,
        },

        targetToBase: {
            result: Covariant.distinct // Should this be yes?
        }
    };
    runTest(test);
}

@("xtest46-delegate")
unittest
{
    Test test = {
        code: q{
            // static assert(is(void delegate(ref const int*) : void delegate(ref int*)));

            struct T
            {
                void base(void delegate(ref int*));
                void target(void delegate(ref const int*)) const;
            }
        },

        baseToTarget: {
            result: Covariant.distinct,
        },

        targetToBase: {
            result: Covariant.distinct
        }
    };
    runTest(test);
}

//========================================================================================
// Utility types / methods
//

/// Test configuration declaring the input types and expected return values
/// when applying `Type.covariant` in any direction
struct Test
{
    string code;         /// Source code declaring the function `base` and `target` which denote the tested `TypeFunction`'s
    Result baseToTarget; /// Expected result of `typeof(base).covariant(typeof(target))`
    Result targetToBase; /// Expected result of `typeof(target).covariant(typeof(base))`
}

/// Expected output from `Type.Covariant`
struct Result
{
    Covariant result = cast(Covariant) -1; /// Return value
    StorageClass suggestion;               /// Storage class suggestion returned in `pstc`
}

/++
 + Parses the source code and verifies that
 +
 + => `typeof(base).covariant(typeof(target))` yields `test,baseToTarget`
 +
 + (Optionally)
 + => `typeof(target).covariant(typeof(base))` yields `test.targetToBase`
 +
 + Params:
 +   test = test configuration
 +   line = location used for error messages
 +/
void runTest(const ref Test test, const size_t line = __LINE__)
{
    initializeFrontend();
    scope (exit) deinitializeFrontend();

    with (extractFunctions(test.code, line))
    {
        testCovariant(base.type, target.type, test.baseToTarget, line);

        // Reversed test is optional
        if (test.targetToBase != Result.init)
            testCovariant(target.type, base.type, test.targetToBase, line);
    }
}

/// Wrapper struct holding the function declarations passed to `Type.covariant`
struct Config
{
    ///
    FuncDeclaration base, target;
}

/++
 + Compiles the source code and searches the resulting AST for functions named
 + `base` and `target`.
 +
 + Params:
 +   code = the source code
 +   line = location used for error messages
 +/
Config extractFunctions(const string code, const size_t line)
{
    import dmd.func : FuncDeclaration;
    import dmd.visitor : SemanticTimeTransitiveVisitor;

    auto result = compiles(code);
    enforce(!!result, line, "Semantic analysis failed with errors");

    /// Visitor that searches the AST for the `FuncDeclaration`'s named `base` and `target`
    extern (C++) static final class TestVisitor : SemanticTimeTransitiveVisitor
    {
        Config config;

        alias visit = typeof(super).visit;

        override void visit(FuncDeclaration fd)
        {
            assert(fd);
            assert (fd.ident);

            if (fd.ident.toString() == "base")
                config.base = fd;
            else if (fd.ident.toString() == "target")
                config.target = fd;
            else
                assert(false, "Unexpected function!");
        }
    }

    scope visitor = new TestVisitor();
    (cast() result.module_).accept(visitor);
    enforce(!!visitor.config.base, line, "No FuncDeclaration `base` found!");
    enforce(!!visitor.config.target, line, "No FuncDeclaration `target` found!");
    return visitor.config;
}

/++
 + Verifies that `base.covariant(target)` yields `expected`.
 +
 + Params:
 +   base     = replacement type
 +   target   = type to be substituted
 +   expected = the expected return values
 +   line     = location used for error messages
 +/
void testCovariant(Type base, Type target, in Result expected, const size_t line = __LINE__)
{
    import dmd.globals : global;
    assert(base);
    assert(target);

    StorageClass actualStc;
    const actual = base.covariant(target, &actualStc);
    enforce(!global.errors, line, "`covariant` raised an error!");

    enforce(actual == expected.result, line, cast(string) (
        "Unexpected result!\n\n" ~
        "base  : `" ~ base.toString() ~ "`\n\n" ~
        "target: `" ~ target.toString() ~ "`\n\n" ~
        "`base.covariant(target)` yields " ~ toString(actual) ~ " instead of " ~ toString(expected.result) ~ '\n'
    ));

    enforce(actualStc == expected.suggestion, line, cast(string) (
        "Unexpected suggestion!\n\n" ~
        "base  : `" ~ base.toString() ~ "`\n\n" ~
        "target: `" ~ target.toString() ~ "`\n\n" ~
        "`base.covariant(target)` suggests " ~ toString(actualStc) ~ " instead of " ~ toString(expected.suggestion) ~ '\n'
    ));
}

/++
 + Converts the given `Covariant` value to `string`.
 +
 + Params:
 +   cv = covariance value
 +
 + Returns: the string representation of `cv`
 +/
string toString(const Covariant cv) pure nothrow @safe
{
    static immutable members = [ __traits(allMembers, Covariant) ];
    if ((cast(ulong) cv) >= members.length)
        return "<Malformed Covariant value>";
    return members[cv];
}

/++
 + Formats the given StorageClass value as an array of STC's members,
 + e.g. `STC.const_ | STC.shared_` is printed as `[const_, shared_]`.
 +
 + Params:
 +   stc = bitfield consisting of STC's entries
 +
 + Returns: the string representation of `stc`
 +/
string toString(const StorageClass stc) pure nothrow @safe
{
    import core.bitop : popcnt;

    string result = "[";
    bool first = true;

    foreach (const member; __traits(allMembers, STC))
    {
        enum val = __traits(getMember, STC, member);
        if ((stc & val) == 0 || popcnt(val) > 1)
            continue;

        if (first)
            first = false;
        else
            result ~= ", ";

        result ~= member;
    }
    result ~= "]";
    return result;
}

/// Custom assert function that overrides the line number to point to the current test
/// instead of the utility methods
void enforce(const bool check, const size_t line, lazy const string msg)  pure @safe
{
    import core.exception : AssertError;
    if (!check)
        throw new AssertError(msg, __FILE__, line);
}

//========================================================================================
// Common setup identical to the other tests:
//

/// Initialize the frontend before each test
@beforeEach void initializeFrontend()
{
    import dmd.frontend : initDMD;
    initDMD();
}

/// Deinitialize the frontend after each test
@afterEach void deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}
