// PERM_RUN:
// REQUIRED_ARGS:

// Tests @trusted { ... } and @system { ... } statement and expression blocks

void systemFunc() @system
{
}

void testStatement() @safe
{
    int x = 10;
    @trusted {
        int* p = &x;
        *p = 20;
        systemFunc();
    }
    @trusted {
        x += 2;
    };
    assert(x == 22);
}

void testSystemBlock() @system
{
    int y = 5;
    @system {
        int* py = &y;
        *py = 15;
        systemFunc();
    }
    @system {
        y += 3;
    };
    assert(y == 18);
}

int testReturnInBlock() @safe
{
    @trusted {
        return 42;
    }
    return 0;
}

int testExp() @safe
{
    int val = @trusted {
        systemFunc();
        return 123;
    };
    return val;
}

int testSystemExpBlock() @system
{
    int b = @system {
        systemFunc();
        return 200;
    };
    return b;
}

void main() @safe
{
    testStatement();
    assert(testReturnInBlock() == 42);
    assert(testExp() == 123);
    @trusted {
        testSystemBlock();
        assert(testSystemExpBlock() == 200);
    }
}
