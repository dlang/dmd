// PERMUTE_ARGS:

import std.range;
import std.stdio;

struct Foo {
    static int[] destroyed;
    int x;
    ~this() { destroyed ~= x; }
};

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
    // The test case from the original bug report.
    auto input = std.stdio.File("runnable/extra-files/test9068.txt", "r");
    string result;
X:  foreach (line; input.byLine()) {
       switch(line.front) {
           case 'q': break X;
           default: result ~= line;
       }
    }
    assert(result == "asdfzxcv", std.conv.text("result is ", result));

    //----------------------------------------
    // Simpler case: the compiler error had nothing to do with the switch.
    input.rewind();
    result = "";
loop_with_range:
    foreach (line; input.byLine()) {
        result ~= line;
        break loop_with_range;
    }
    assert(result == "asdf", std.conv.text("result is ", result));

    //----------------------------------------
    // Test with destructors: the loop is implicitly wrapped into two
    // try/finally clauses.
loop_with_dtors:
    for (auto x = Foo(4), y = Foo(5); x.x != 10; ++x.x) {
        if (x.x == 8)
            break loop_with_dtors;
    }
    assert(Foo.destroyed == [5, 8],
           std.conv.text("Foo.destroyed is ", Foo.destroyed));
    Foo.destroyed.clear();

    //----------------------------------------
    // Same with an unlabelled break.
    for (auto x = Foo(4), y = Foo(5); x.x != 10; ++x.x) {
        if (x.x == 7)
            break;
    }
    assert(Foo.destroyed == [5, 7],
           std.conv.text("Foo.destroyed is ", Foo.destroyed));
    Foo.destroyed.clear();
}

void main() {
    Bug9068();
}
