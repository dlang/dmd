// PERMUTE_ARGS:

struct Foo {
    static int[] destroyed;
    int x;
    ~this() { destroyed ~= x; }
}


struct SimpleCounter {
    static int destroyedCount;
    const(int) limit = 5;
    int counter;
    ~this() { destroyedCount++; }

    // Range primitives.
    @property bool empty() const { return counter >= limit; }
    @property int front() { return counter; }
    void popFront() { counter++; }
}


// ICE when trying to break outer loop from inside switch statement
void Bug9068() {

    //----------------------------------------
    // There was never a bug in this case (no range).
    int sum;
loop_simple:
    foreach (i; [10, 20]) {
        sum += i;
        break loop_simple;
    }
    assert(sum == 10);

    //----------------------------------------
    // There was a bug with loops over ranges.
    int last = -1;
X:  foreach (i; SimpleCounter()) {
       switch(i) {
           case 3: break X;
           default: last = i;
       }
    }
    assert(last == 2);
    assert(SimpleCounter.destroyedCount == 1);

    //----------------------------------------
    // Simpler case: the compiler error had nothing to do with the switch.
    last = -1;
loop_with_range:
    foreach (i; SimpleCounter()) {
        last = i;
        break loop_with_range;
    }
    assert(last == 0);
    assert(SimpleCounter.destroyedCount == 2);

    //----------------------------------------
    // Test with destructors: the loop is implicitly wrapped into two
    // try/finally clauses.
loop_with_dtors:
    for (auto x = Foo(4), y = Foo(5); x.x != 10; ++x.x) {
        if (x.x == 8)
            break loop_with_dtors;
    }
    assert(Foo.destroyed == [5, 8]);
    Foo.destroyed.clear();

    //----------------------------------------
    // Same with an unlabelled break.
    for (auto x = Foo(4), y = Foo(5); x.x != 10; ++x.x) {
        if (x.x == 7)
            break;
    }
    assert(Foo.destroyed == [5, 7]);
    Foo.destroyed.clear();
}

void main() {
    Bug9068();
}
