// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

static if (true)
abstract:
    static if (false)
        class G5 {}
else
    class G6 {}

