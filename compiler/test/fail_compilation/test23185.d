// https://github.com/dlang/dmd/issues/23185

/*
TEST_OUTPUT:
---
fail_compilation/test23185.d(11): Error: no `default` or `case` for `3` in `switch` statement
fail_compilation/test23185.d(15):        called from here: `(*function () pure nothrow @nogc @safe => 0)()`
---
*/
enum x = () {
    final switch (3) {
        case 1: break;
    }
    return 0;
} ();
