// REQUIRED_ARGS: -unittest

import core.stdc.stdio, core.exception;
import std.math;

int main() {
    printf("Success\n");
    return 0;
}

unittest {
    int a = 2;
    assert(a == 2, "");
    assert(a == 2);

    bool assertCaught = false;
    a = 3456;
    try {
        assert(a == 2, "original message");
    } catch (AssertError e) {
        assert(e.msg == "original message");
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }

    try {
        assert(a == 2);
    } catch (AssertError e) {
        assert(e.msg == "3456 == 2  is unexpected");
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

unittest {
    int a = 4;
    bool assertCaught = false;
    try {
        assert(a * a * a <= 1);
    } catch (AssertError e) {
        assert(e.msg == "64 <= 1  is unexpected");
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

unittest {
    int a;
    auto b = &a;
    bool assertCaught = false;
    try {
        assert(null is b);
    } catch (AssertError e) {
        assert(e.msg[0..8] == "null is " && e.msg[$-15..$] == "  is unexpected");
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

unittest {
    string c = "hello", d = "world";
    bool assertCaught = false;
    try {
        assert(c > d);
    } catch (AssertError e) {
        assert(e.msg == `"hello" > "world"  is unexpected`);
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

unittest {
    double d = 0.6;
    assert(d == 0.6);
}

unittest {
    real k = 1.4;
    assert(k * 1.2 == k * 0.6 * 2);
}

unittest {
    char[5][] a = ["hello"];
    assert(a[0] == "hello");
}

unittest {
    int[5] a = [1, 2, 3, 4, 5];
    assert(a == [1, 2, 3, 4, 5]);
    bool assertCaught = false;
    try {
        assert(a[] == [5, 4, 3, 2, 1]);
    } catch (AssertError e) {
        assert(e.msg == "[1, 2, 3, 4, 5] == [5, 4, 3, 2, 1]  is unexpected");
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

struct S105 {
    string s;
    string toString() { return `S105("` ~ s ~ `")`; }
    bool opEquals(ref const S105 other) const { return false; }
}
unittest {
    const a = S105("hi");
    bool assertCaught = false;
    try {
        assert(a == a);
    } catch (AssertError e) {
        assert(e.msg == `const(S105)("hi").opEquals(const(S105)("hi"))  is unexpected`);
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

class C123 {
    string s;
    override string toString() { return `C123("` ~ s ~ `")`; }
    override bool opEquals(const Object other) const pure nothrow @safe { return false; }
}
unittest {
    auto a = new C123, b = new C123;
    a.s = "hi";
    b.s = "bye";
    bool assertCaught = false;
    try {
        assert(a == b);
    } catch (AssertError e) {
        assert(e.msg == `opEquals(C123("hi"), C123("bye"))  is unexpected`);
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

unittest {
    string s = "%s";
    bool assertCaught = false;
    try {
        assert(s != "%s");
    } catch (AssertError e) {
        assert(e.msg == `"%s" != "%s"  is unexpected`);
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

unittest {
    int x = 4;
    bool assertCaught = false;
    assert(x == 3 || x == 4 || x == 5);
    try {
        assert(x == 6 || x == 7);
    } catch (AssertError e) {
        assert(e.msg == "4 == 6 || 4 == 7  is unexpected");
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

unittest {
    int x = 60;
    bool assertCaught = false;
    assert(x % 2 == 0 && x % 3 == 0 && x % 5 == 0);
    try {
        assert(x % 6 == 0 && x % 7 == 0);
    } catch (AssertError e) {
        assert(e.msg == "0 == 0 && 4 == 0  is unexpected");
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

unittest {
    double t = 122.4;
    assert(feqrel(t, 122.5) >= 8);
    bool assertCaught = false;
    try {
        assert(feqrel(t, 123.5) >= 8);
    } catch (AssertError e) {
        assert(e.msg == "feqrel(122.4, 123.5) >= 8  is unexpected");
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

unittest {
    double t = 122.4;
    bool assertCaught = false;
    try {
        assert(!approxEqual(t, t));
    } catch (AssertError e) {
        assert(e.msg == "!approxEqual(122.4, 122.4)  is unexpected");
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}

unittest {
    function() pure nothrow {
        bool assertCaught = false;
        int f = 3;
        try {
            function(int f) pure nothrow @safe {
                assert(f == 5);
            }(f);
        } catch (AssertError e) {
            function(in AssertError e) pure nothrow @safe {
                assert(e.msg == "3 == 5  is unexpected");
            }(e);
            assertCaught = true;
        } finally {
            assert(assertCaught);
        }
    }();
}

struct SS {
    string d;
    bool opEquals(const ref SS other) const pure nothrow @safe { return d == other.d; }
    this(this) @system {}
}

unittest {
    bool assertCaught = false;
    auto a = SS("4");
    auto b = a;
    b.d = "t";
    try {
        assert(a == b);
    } catch (AssertError e) {
        assertCaught = true;
    } finally {
        assert(assertCaught);
    }
}


