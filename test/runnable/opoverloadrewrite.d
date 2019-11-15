template opUnary(string op) {
    static if (op == "+")
        string opUnary(string name) {
            return "hello " ~ name;
        }
}
int opCmp(T1, T2)(T1 a, T2 b) {
    return -1;
}
struct ArbitraryStruct {

}
void main() {
    auto firstform = +`undefinedName`;
    auto secondform = `undefinedName`.opUnary!("+");
    assert(firstform == secondform);
    ArbitraryStruct a;
    ArbitraryStruct b;
    assert(a < b);
    assert(b < a);
}
