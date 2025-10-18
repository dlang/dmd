// https://issues.dlang.org/show_bug.cgi?id=6556

debug=BUG;

shared static this() {
    debug(BUG) import imports.test61a;
    assert(bar() == 12);
}
