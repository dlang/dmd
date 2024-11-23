/*
TEST_OUTPUT:
---
fail_compilation/fail20616.d(24): Error: undefined identifier `$`
    auto x = X()[0 .. $];
                      ^
fail_compilation/fail20616.d(24):        Aggregate declaration 'X()' does not define 'opDollar'
    auto x = X()[0 .. $];
                ^
fail_compilation/fail20616.d(26): Error: undefined identifier `$`
    auto c = b[0 .. $ - 1];
                    ^
fail_compilation/fail20616.d(26):        Aggregate declaration 'b' does not define 'opDollar'
    auto c = b[0 .. $ - 1];
              ^
---
*/
module fail20616;

void g() {
    struct X {
        auto opSlice(size_t a, size_t b) { return ""; }
    }
    auto x = X()[0 .. $];
    auto b = X();
    auto c = b[0 .. $ - 1];
    auto v = [1, 2, 3];
    auto d = v[$.. $];
}

int main() {
    g();
    return 0;
}
