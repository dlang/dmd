struct Foo {
    ~this() { throw new Exception(""); }
}
nothrow void main() {
    Foo f;
    goto NEXT;
    NEXT:;
}
