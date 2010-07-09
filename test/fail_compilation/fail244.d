import std.stdio;

struct ClassWithDeps {
    deprecated int value;
    deprecated static int staticValue;

    void test(ClassWithDeps obj) {
        obj.value = 666;
        obj.staticValue = 102;
        this.value = 666;
        this.staticValue = 103;
        ClassWithDeps.staticValue = 104;
        writefln(obj.value);
        writefln(obj.staticValue);
        writefln(this.value);
        writefln(this.staticValue);
        writefln(ClassWithDeps.staticValue);
    }
}

