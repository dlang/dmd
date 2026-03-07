// Test for @__ctfe attribute

int add(int a) @__ctfe => a + 2;

void main() {
    // OK: CTFE-only call
    enum y = add(6);
    static assert(y == 8);

    // CTFE with intermediate variable
    enum z = add(add(1));
    static assert(z == 5);
}
