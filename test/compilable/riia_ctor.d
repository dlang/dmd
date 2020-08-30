// https://issues.dlang.org/show_bug.cgi?id=17494
struct S
{
    ~this() {}
}

class C
{
    S s;

    this() nothrow {}
}

// https://issues.dlang.org/show_bug.cgi?id=17506
struct TreeMap
{
    this() @disable;
    this(TTree tree) { this.tree = tree; }
    TTree tree;
}

struct TTree
{
    this() @disable;
    this(int foo) {}
    ~this() {}
}
