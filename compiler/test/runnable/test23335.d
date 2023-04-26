// https://issues.dlang.org/show_bug.cgi?id=23335

void main() {

    int k;

    fun2 = (a) { k = 42; };
    fun(2);
    assert(k == 42);
}

void delegate(int) fun;

ref void delegate(int) fun2() {
    return fun;
}
