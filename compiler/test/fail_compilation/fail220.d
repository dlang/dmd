/*
TEST_OUTPUT:
---
fail_compilation/fail220.d(20): Error: identifier expected for template value parameter
    static if (is (T V : V[K], K == class)) {
                                 ^
fail_compilation/fail220.d(20): Error: found `==` when expecting `)`
    static if (is (T V : V[K], K == class)) {
                                 ^
fail_compilation/fail220.d(20): Error: found `class` when expecting `)`
    static if (is (T V : V[K], K == class)) {
                                    ^
fail_compilation/fail220.d(20): Error: declaration expected, not `)`
    static if (is (T V : V[K], K == class)) {
                                         ^
fail_compilation/fail220.d(24): Error: unmatched closing brace
---
*/
template types (T) {
    static if (is (T V : V[K], K == class)) {
        static assert (false, "assoc");
    }
    static const int types = 4;
}

int i = types!(int);
