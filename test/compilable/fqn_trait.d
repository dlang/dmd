    private struct QualifiedNameTests
    {
        struct Inner
        {
        }
        Inner *ptr;
        Inner **ptrPtr;

        ref const(Inner[string]) func( ref Inner var1, lazy scope string var2 );
        struct Data(T) { int x; }
        void tfunc(T...)(T args) {}
        template Inst(alias A) { int x; }
        class Test12309(T, int x, string s) {}
    }

    private enum QualifiedEnum
    {
        a = 42
    }

    enum fqn(alias s) = __traits(fullyQualifiedName, s);
    enum fqn(T) = __traits(fullyQualifiedName, T);
    import std.traits : fullyQualifiedName;


    alias qnTests = QualifiedNameTests;
    enum prefix = __MODULE__ ~ ".QualifiedNameTests.";
    static assert(fqn!(qnTests.Inner)           == prefix ~ "Inner");
    static assert(fqn!(qnTests.func)            == prefix ~ "func");
    static assert(fqn!(qnTests.Data!int)        == prefix ~ "Data!(int)");
    static assert(fqn!(qnTests.Data!int.x)      == prefix ~ "Data!(int).x");
    static assert(fqn!(qnTests.tfunc!(int[]))   == prefix ~ "tfunc!(int[])");
    static assert(fqn!(qnTests.Inst!(Object))   == prefix ~ "Inst!(object.Object)");
    static assert(fqn!(qnTests.Inst!(Object).x) == prefix ~ "Inst!(object.Object).x");
    static assert(fqn!(qnTests.Test12309!(int, 10, "str")) == prefix ~ "Test12309!(int, 10, \"str\")");
    static assert(fqn!(QualifiedEnum.a) == __MODULE__ ~  ".QualifiedEnum.a");
    static assert(fqn!(typeof(QualifiedEnum.a)) == __MODULE__ ~  ".QualifiedEnum");
    static assert(fqn!(typeof(qnTests.ptr)) == prefix ~  "Inner*");
    static assert(fqn!(typeof(qnTests.ptrPtr)) == prefix ~  "Inner**");

    import core.sync.barrier;
    static assert(fqn!Barrier == "core.sync.barrier.Barrier");
