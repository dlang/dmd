
const(Object)ref test() {
    return new Object;
}

void main() {
    auto obj = test();
    static assert(is(typeof(obj) == const(Object)ref));
    static assert(!is(typeof(obj) == const(Object)));
}