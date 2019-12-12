/* TEST_OUTPUT:
---
fail_compilation/b17259.d: Error: overloadset `b17259.C.__ctor` is aliased to a function
---
*/
mixin template Templ(T) {
    this(T) {}
}

class C {
    mixin Templ!int;
    mixin Templ!string;
}

void main() {
    auto c = new C("should work");
}
