// PERMUTE_ARGS: -unittest
// REQUIRED_ARGS: -D -w -o- -c -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh unittest

module ddocunittest;

/* Insert test-cases for documented unittests feature here. */

/// foo function - 1 example
int foo(int a, int b) { return a + b; }

///
unittest
{
    assert(foo(1, 1) == 2);
}

/// bar function - 1 example
bool bar() { return true; }

///
unittest
{
    // documented
    assert(bar());
}

/// placeholder
unittest
{
}

/// doo function - no examples
void doo() { }

///
private unittest
{
    // undocumented
    doo();
}

unittest
{
    // undocumented
    doo();
}

/**
add function - 3 examples

Examples:

----
assert(add(1, 1) == 2);
----
*/
int add(int a, int b) { return a + b; }

///
unittest
{
    // documented
    assert(add(3, 3) == 6);
    assert(add(4, 4) == 8);
}

unittest
{
    // undocumented
    assert(add(2, 2) + add(2, 2) == 8);
}

///
unittest
{
    // documented
    assert(add(5, 5) == 10);
    assert(add(6, 6) == 12);
}

/// class Foo
immutable pure nothrow class Foo
{
    int x;

    ///
    unittest
    {
        // another foo example
        Foo foo = new Foo;
    }
}

///
unittest
{
    Foo foo = new Foo;
}

pure
{
    const
    {
        immutable
        {
            /// some class - 1 example
            class SomeClass {}
        }
    }
}

///
unittest
{
    SomeClass sc = new SomeClass;
}

/// Outer - 1 example
class Outer
{
    /// Inner
    static class Inner
    {
    }

    ///
    unittest
    {
        Inner inner = new Inner;
    }
}

///
unittest
{
    Outer outer = new Outer;
}

/** foobar - no examples */
void foobar()
{
}

unittest
{
    foobar();
}

/**
func - 4 examples
Examples:
---
foo(1);
---

Examples:
---
foo(2);
---
*/
void foo(int x) {  }

///
unittest
{
    foo(2);
}

///
unittest
{
    foo(4);
}

// ------------------------------------
// 9474

///
void foo9474() { }

version(none)
unittest { }

/// Example
unittest { foo9474(); }

/// doc
void bar9474() { }

version(none)
unittest { }

/// Example
unittest { bar9474(); }

///
struct S9474
{
}
///
unittest { S9474 s; }

///
auto autovar9474 = 1;
///
unittest { int v = autovar9474; }

///
auto autofun9474() { return 1; }
///
    unittest { int n = autofun9474(); }

///
template Template9474()
{
    /// Shouldn't link following unittest to here
    void foo() {}
}
///
unittest { alias Template9474!() T; }

// ------------------------------------
// 9713

///
void fooNoDescription() {}
///
unittest { fooNoDescription(); }
///
unittest { if (true) {fooNoDescription(); } /* comment */ }

// ------------------------------------

/// test for bugzilla 9757
void foo9757() {}
/// ditto
void bar9757() {}
/// ditto
void baz9757() {}
///
unittest { foo9757(); bar9757(); }
///
unittest { bar9757(); foo9757(); }

/// with template functions
auto redBlackTree(E)(E[] elems...)
{
    return 1;
}
/// ditto
auto redBlackTree(bool allowDuplicates, E)(E[] elems...)
{
    return 2;
}
/// ditto
auto redBlackTree(alias less, E)(E[] elems...)
{
    return 3;
}
///
unittest
{
    auto rbt1 = redBlackTree(0, 1, 5, 7);
    auto rbt2 = redBlackTree!string("hello", "world");
    auto rbt3 = redBlackTree!true(0, 1, 5, 7, 5);
    auto rbt4 = redBlackTree!"a > b"(0, 1, 5, 7);
}

// ------------------------------------
// Issue 9758

/// test
void foo(){}

///
unittest {  }

// ------------------------------------
// Issue 10519

///
bool balancedParens10519(string, char, char) { return true; }
///
unittest
{
    auto s = "1 + (2 * (3 + 1 / 2)";
    assert(!balancedParens10519(s, '(', ')'));
}

// ------------------------------------

void main() { }
