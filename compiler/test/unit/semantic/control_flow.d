// Tests regarding src/dmd/blockexit.d
//
// See ../../README.md for information about DMD unit tests.

module semantic.control_flow;

import dmd.blockexit : BE;
import dmd.func : FuncDeclaration;
import dmd.statement : Statement;
import dmd.visitor : Visitor;

import support;

//========================================================================================
// Sanity checks for simple statements
//

unittest { testStatement(`int i;`, BE.fallthru); }

unittest { testStatement(`return;`, BE.return_); }

unittest { testStatement(`void mayThrow(); return mayThrow();`, BE.return_ | BE.throw_); }

unittest { testStatement(`throw new Exception("");`, BE.throw_); }

unittest { testStatement(`throw new Error("");`, BE.errthrow); }

// ENHANCEMENT: Could detect that this expression always throws
unittest { testStatement(`false || throw new Exception("");`, BE.throw_ | BE.fallthru); }

unittest { testStatement(`false || throw new Error("");`, BE.errthrow | BE.fallthru); }

unittest { testStatement(`assert(0);`, BE.halt); }

unittest { testStatement(`int i; assert(i);`, BE.fallthru); } // Should this include errthrow?

/// Checks that `blockExit` yields `expected` for the given `code`.
void testStatement(const string stmt, const BE expected)
{
    const code = "void test() {\n" ~ stmt ~ "\n}";
    executeTest(code, (fd) {
        testBlockExit(fd, fd.fbody, expected);
    });
}

//========================================================================================
// Sanity checks for nested statements
//

@("if-else")
unittest
{
    executeTest(q{
        void test(int i)
        {
            if (i)
                throw new Exception("");
            else
                return;
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 1);

        auto if_ = (*stmts)[0].isIfStatement();
        assert(if_);

        testBlockExit(fd, fd.fbody, BE.throw_ | BE.return_);
        testBlockExit(fd, if_, BE.throw_ | BE.return_);

        testBlockExit(fd, if_.ifbody, BE.throw_);
        testBlockExit(fd, if_.elsebody, BE.return_);
    });
}

@("while")
unittest
{
    executeTest(q{
        int mayThrow();
        int i;

        void test()
        {
            mayThrow();

            while (i) { i++; }

            while (mayThrow()) {}

            while (i) { mayThrow(); }

            while (true) { assert(0); }

            while (true) { continue; }
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 6);

        // Calling mayThrow might throw
        testBlockExit(fd, (*stmts)[0], BE.fallthru | BE.throw_);

        // Increment loop
        testBlockExit(fd, (*stmts)[1], BE.fallthru);

        // Calling mayThrow somewhere in the loop
        testBlockExit(fd, (*stmts)[2], BE.fallthru | BE.throw_);
        testBlockExit(fd, (*stmts)[3], BE.fallthru | BE.throw_);

        // Infinite loops
        testBlockExit(fd, (*stmts)[4], BE.halt);
        testBlockExit(fd, (*stmts)[5], BE.none);
    });
}

@("do-while")
unittest
{
    executeTest(q{
        int mayThrow();

        void test()
        {
            do {} while (false);

            do { mayThrow(); } while (false);

            do {} while (mayThrow());

            do { assert(0); } while (mayThrow());

            do { break; } while (true);
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 5);

        // No-op loop
        testBlockExit(fd, (*stmts)[0], BE.fallthru);

        // Calling mayThrow somewhere in the loop
        testBlockExit(fd, (*stmts)[1], BE.fallthru | BE.throw_);
        testBlockExit(fd, (*stmts)[2], BE.fallthru | BE.throw_);

        // Aborted before calling mayThrow
        testBlockExit(fd, (*stmts)[3], BE.halt);

        // Skipped infinite loop
        testBlockExit(fd, (*stmts)[4], BE.fallthru);
    });
}

@("for")
unittest
{
    executeTest(q{
        int mayThrow();

        void test()
        {
            for (int i = 0; i < 1; i++) {}

            for (int i = mayThrow(); i < 1; i++) {}

            for (int i = 0; i < mayThrow(); i++) {}

            for (int i = 0; i < 1; i += mayThrow()) {}

            for (int i = 0; i < 1; i++)
                mayThrow();
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 5);

        // No-op loop
        testBlockExit(fd, (*stmts)[0], BE.fallthru);

        // Calling mayThrow somewhere in the loop
        testBlockExit(fd, (*stmts)[1], BE.fallthru | BE.throw_);
        testBlockExit(fd, (*stmts)[2], BE.fallthru | BE.throw_);
        testBlockExit(fd, (*stmts)[3], BE.fallthru | BE.throw_);
        testBlockExit(fd, (*stmts)[4], BE.fallthru | BE.throw_);
    });
}

@("foreach-array")
unittest
{
    executeTest(q{
        int[] mayThrow();

        void test()
        {
            foreach (i; [1, 2, 3]) {}

            foreach (i; mayThrow()) {}

            foreach (i; [1, 2, 3]) { mayThrow(); }
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 3);

        // No-op loop
        testBlockExit(fd, (*stmts)[0], BE.fallthru);

        // Calling mayThrow somewhere in the loop
        testBlockExit(fd, (*stmts)[1], BE.fallthru | BE.throw_);
        testBlockExit(fd, (*stmts)[2], BE.fallthru | BE.throw_);
    });
}

@("foreach-range")
unittest
{
    executeTest(q{
        struct Range
        {
            bool empty() const;
            int front() const;
            void popFront();
        }

        void test()
        {
            foreach (i; Range()) {}
        }
    },
    (FuncDeclaration fd)
    {

        auto stmts = getStatements(fd);
        assert(stmts.length == 1);

        testBlockExit(fd, (*stmts)[0], BE.fallthru | BE.throw_);
    });
}

@("foreach-tuple")
unittest
{
    executeTest(q{
        struct Range
        {
            int a;
            double b;
        }

        void test()
        {
            Range r;
            foreach (ref m; r.tupleof)
                m = 1;

            foreach (ref m; r.tupleof)
                return;
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 3);

        testBlockExit(fd, (*stmts)[0], BE.fallthru);
        testBlockExit(fd, (*stmts)[1], BE.fallthru);
        testBlockExit(fd, (*stmts)[2], BE.return_);
    });
}

@("switch-case")
unittest
{
    executeTest(q{
        int mayThrow();

        void test(int i)
        {
            final switch (i)
            {
                case 1: break;
            }

            switch (i)
            {
                case 0:
                case 1: break;
                case 2: goto default;
                default:
                case 3: goto case 2;
            }

            final switch (i)
            {
                case 1: mayThrow(); break;
            }

            final switch (mayThrow())
            {
                case 1: break;
            }
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 4);

        // final switch might pass or abort on invalid values
        const baseline = BE.fallthru | BE.halt;
        testBlockExit(fd, (*stmts)[0], baseline);

        // Complex control flow inside switch-case
        // ENHANCEMENT: goto never leaves the switch-case
        testBlockExit(fd, (*stmts)[1], BE.fallthru | BE.goto_);

        // Calling mayThrow might throw
        testBlockExit(fd, (*stmts)[2], baseline | BE.throw_);
        testBlockExit(fd, (*stmts)[3], baseline | BE.throw_);
    });
}

@("try-catch-caught")
unittest
{
    executeTest(q{
        void mayThrow();

        void test()
        {
            try { mayThrow(); } catch (Exception e) {}

            try { mayThrow(); throw new Error(""); } catch (Throwable) {}

            try { mayThrow(); } catch (Throwable) { throw new Exception(""); }
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 3);

        // Calls mayThrow but catches all exceptions
        testBlockExit(fd, (*stmts)[0], BE.fallthru);

        // Throws and catches Error
        auto tc = (*stmts)[1].isTryCatchStatement();
        testBlockExit(fd, tc, BE.fallthru);

        // Throws from handler
        tc = (*stmts)[2].isTryCatchStatement();
        testBlockExit(fd, tc, BE.fallthru | BE.throw_);
    });
}

@("try-catch-escape")
unittest
{
    executeTest(q{
        void mayThrow();

        void test()
        {
            try { mayThrow(); } catch (Error e) {}

            try { mayThrow(); throw new Error(""); } catch (Exception) {}
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 2);

        // Throws exception but catches Error
        auto tc = (*stmts)[0].isTryCatchStatement();
        testBlockExit(fd, tc, BE.fallthru | BE.throw_);

        // Throws exception + error but only catches Exception
        tc = (*stmts)[1].isTryCatchStatement();
        testBlockExit(fd, tc, BE.fallthru | BE.errthrow);
    });
}

@("try-catch-skipped")
unittest
{
    executeTest(q{
        void test()
        {
            try {} catch (Exception) {}
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 0);
    });
}

@("try-finally")
unittest
{
    executeTest(q{
        void mayThrow();
        void neverThrows() nothrow;

        void test()
        {
            { try mayThrow(); finally neverThrows(); }

            { try neverThrows(); finally mayThrow(); }
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 2);

        testBlockExit(fd, (*stmts)[0], BE.fallthru | BE.throw_);
        testBlockExit(fd, (*stmts)[1], BE.fallthru | BE.throw_);
    });
}

@("try-finally-override")
unittest
{
    executeTest(q{
        void mayThrow();

        void test()
        {
            { try mayThrow(); finally throw new Error(""); }

            { try throw new Error(""); finally mayThrow(); }
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 2);

        // ENHANCEMENT: finally block trumps the try-block
        testBlockExit(fd, (*stmts)[0], BE.throw_ | BE.errthrow);
        testBlockExit(fd, (*stmts)[1], BE.throw_ | BE.errthrow);
    });
}

@("scope-exit")
unittest
{
    executeTest(q{
        void test()
        {
            scope (exit) throw new Exception("");
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        // FIXME: null statement without errors?!?
        assert(stmts.length == 2);
        assert((*stmts)[0] is null);
        testBlockExit(fd, (*stmts)[1], BE.throw_);
    });
}

@("scope-success")
unittest
{
    executeTest(q{
        void test()
        {
            scope (success) throw new Exception("");
        }
    },
    (FuncDeclaration fd)
    {
        // Rewritten as:
        // bool __os2 = false;
        // try
        // {
        // }
        // catch(Throwable __o3)
        // {
        //     __os2 = true;
        //     throw __o3;
        // }
        // if (!__os2)
        //     throw new Exception("");
        //
        // FIXME: null statement at index 1 without errors?!?
        auto stmts = getStatements(fd);
        assert(stmts.length == 4);

        // BUG(?): blockexit yields `fallthru` for the try-catch because the exception is typed as `Throwable`
        testBlockExit(fd, (*stmts)[2], BE.fallthru);
        assert((*stmts)[2].isTryCatchStatement());

        testBlockExit(fd, fd.fbody, BE.fallthru | BE.throw_);
    });
}

@("scope-failure")
unittest
{
    executeTest(q{
        void test()
        {
            scope (failure) throw new Exception("");
            throw new Exception("");
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        // FIXME: null statement without errors?!?
        assert(stmts.length == 2);
        assert((*stmts)[0] is null);
        assert((*stmts)[1] !is null);
        testBlockExit(fd, (*stmts)[1], BE.throw_);
    });
}

@("scope-success-skipped")
unittest
{
    executeTest(q{
        void test()
        {
            scope (success) assert(0);
            throw new Exception("");
        }
    },
    (FuncDeclaration fd)
    {
        // Rewritten as
        // bool __os2 = false;
        // try
        // {
        //     try
        //     {
        //         throw new Exception("");
        //     }
        //     catch(Throwable __o3)
        //     {
        //         __os2 = true;
        //         throw __o3;
        //     }
        // }
        // finally
        //     if (!__os2)
        //         assert(0);

        auto stmts = getStatements(fd);
        // FIXME: null statement at index 1 without errors?!?
        assert(stmts.length == 3);

        testBlockExit(fd, (*stmts)[2], BE.throw_ | BE.halt);
        assert((*stmts)[2].isTryFinallyStatement());

        // ENHANCEMENT: Includes BE.halt even though the assert(0) is unreachable!
        testBlockExit(fd, fd.fbody, BE.throw_ | BE.halt);
    });
}

@("scope-failure-skipped")
unittest
{
    executeTest(q{
        void test()
        {
            scope (failure) throw new Exception("");
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 0); // Eliminated because the body is nothrow
    });
}

@("scope-failure-implies-nothrow")
unittest
{
    testStatement(q{
        scope (failure) assert(false);
        throw new Exception("");
    }, BE.halt);
}

@("with")
unittest
{
    executeTest(q{
        struct S
        {
            int a;
        }

        S mayThrow();

        void test()
        {
            with (S(1)) {}

            with (mayThrow()) { assert(0); }

            with (S(1)) { mayThrow(); }
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 3);

        testBlockExit(fd, (*stmts)[0], BE.fallthru);
        testBlockExit(fd, (*stmts)[1], BE.throw_ | BE.halt);
        testBlockExit(fd, (*stmts)[2], BE.fallthru | BE.throw_);

        testBlockExit(fd, fd.fbody, BE.throw_ | BE.halt);
    });
}

@("synchronized-plain")
unittest
{
    executeTest(q{
        void mayThrow();

        void test()
        {
            { synchronized {} }

            { synchronized { mayThrow(); } }
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 2);

        testBlockExit(fd, (*stmts)[0], BE.fallthru);
        testBlockExit(fd, (*stmts)[1], BE.fallthru | BE.throw_);
    });
}

@("synchronized-object")
unittest
{
    executeTest(q{
        Object obj;

        Object mayThrow();

        void test()
        {
            { synchronized(obj) {} }

            { synchronized(obj) { mayThrow(); } }

            { synchronized(mayThrow()) { return; } }
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 3);

        testBlockExit(fd, (*stmts)[0], BE.fallthru | BE.throw_);
        testBlockExit(fd, (*stmts)[1], BE.fallthru | BE.throw_);
        testBlockExit(fd, (*stmts)[2], BE.return_ | BE.throw_);
    });
}

@("goto")
unittest
{
    executeTest(q{
        void test()
        {
            Lstart: {}
            goto Lstart;
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 2);

        testBlockExit(fd, (*stmts)[0], BE.fallthru);
        testBlockExit(fd, (*stmts)[1], BE.goto_);

        // ENHANCEMENT: Could detect the infinite loop
        testBlockExit(fd, fd.fbody, BE.goto_);
    });
}

@("asm")
unittest
{
    executeTest(q{
        void test()
        {
            asm {int 3; }

            asm nothrow {int 3; }
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 2);

        testBlockExit(fd, (*stmts)[0], BE.fallthru | BE.return_ | BE.goto_ | BE.halt | BE.throw_);

        testBlockExit(fd, (*stmts)[1], BE.fallthru | BE.return_ | BE.goto_ | BE.halt);
    });
}

// Pruned statements
@("misc")
unittest
{
    executeTest(q{
        void test()
        {
            pragma(msg, "Hello");

            static assert(1);
        }
    },
    (FuncDeclaration fd)
    {
        auto stmts = getStatements(fd);
        assert(stmts.length == 0);
    });
}

//========================================================================================
// Utilities used by the tests defined above
//

/++
 + Fetches the list of statements from the function body.
 + Unwraps `CompoundStatement`'s consisting of a single statement as necessary.
 +
 + Params:
 +   fd = declaration providing the function  body
 +
 + Returns: a list of top-level statements in the function body
 +/
auto getStatements(FuncDeclaration fd)
{
    assert(fd.fbody);
    auto cs = fd.fbody.isCompoundStatement();
    assert(cs);
    auto stmts = cs.statements;
    assert(stmts);

    // Body sometimes wrapped in additional CompoundStatments?
    while (stmts.length == 1)
    {
        auto s = (*stmts)[0].isCompoundStatement();
        if (!s)
            break;
        stmts = s.statements;
        assert(stmts);
    }

    return stmts;
}
/// Callback implementing the actual test
alias Handler = void delegate(FuncDeclaration);

/++
 + Compiles the given code and applies the callback to the test function found in
 + the resulting AST (or raises an error if no matching `FuncDeclaration` exists).
 +
 + Params:
 +   code = the test code (must contain a function named `test`)
 +   handler = the callback
 +/
void executeTest(const string code, Handler handler)
{
    import dmd.visitor : SemanticTimeTransitiveVisitor;

    /// Visitor that searches the AST for a `FuncDeclaration` named `test`
    extern (C++) static final class TestVisitor : SemanticTimeTransitiveVisitor
    {
        Handler handler;
        bool called;

        extern(D) this(Handler handler)
        {
            assert(handler);
            this.handler = handler;
        }

        alias visit = typeof(super).visit;

        override void visit(FuncDeclaration fd)
        {
            assert(fd);
            if (fd.ident && fd.ident.toString() == "test")
            {
                handler(fd);
                called = true;
            }
        }
    }

    scope visitor = new TestVisitor(handler);
    executeTest(code, visitor);
    assert(visitor.called, "No FuncDeclaration found!");
}

/// Compiles `code` and applies the visitor to the resulting AST.
void executeTest(const string code, Visitor visitor)
{
    assert(code);
    assert(visitor);

    auto res = support.compiles(code);
    if (!res)
    {
        const error = "Test failed!"
                    ~ "\n===========================================\n"
                    ~ code
                    ~ "\n===========================================\n"
                    ~ res.toString();
        assert(false, error);
    }

    auto mod = cast() res.module_;
    assert(mod);
    mod.accept(visitor);
}

/++
 + Formats the given BE value as an array of BE's values,
 + e.g. `BE.throw_ | BE.halt` is printed as `[throw_, halt]`.
 +
 + Params:
 +   be = bitfield consisting of BE's values
 +
 + Returns: the string representation of `be`
 +/
string beToString(const int be)
{
    string result = "[";
    bool first = true;

    foreach (const member; __traits(allMembers, BE))
    {
        enum val = __traits(getMember, BE, member);
        if (val == BE.any || (be & val) == 0)
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

/++
 + Verifiies that `blockexit` yields `expected` when called for the
 + statement `stmt` located inside of a function represented by `fd`.
 +
 + Params:
 +   fd = the function containing `stmt`
 +   stmt = the statement to check
 +   expected = the return values expected from `blockexit`
 +/
void testBlockExit(FuncDeclaration fd, Statement stmt, const BE expected)
{
    import dmd.globals : global;
    import dmd.blockexit : blockExit;

    assert(fd);
    assert(stmt);

    const actual = blockExit(stmt, fd, null);
    assert(actual == expected, beToString(actual) ~ " != " ~ beToString(expected));

    assert(!global.errors, "`blockExit` raised an error!");
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
