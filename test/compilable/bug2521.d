// PERMUTE_ARGS:

immutable int val = 23;
const int val2 = 23;

ref immutable(int) func() {
    return val;
}
ref immutable(int) func2() {
    return *&val;
}
ref immutable(int) func3() {
    return func;
}
ref const(int) func4() {
    return val2;
}
ref const(int) func5() {
    return val;
}
auto ref func6() {
    return val;
}
ref func7() {
    return val;
}

void main() {
}