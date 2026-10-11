/*
TEST_OUTPUT:
---
fail_compilation/test21408.d(12): Error: failed to lower array comparison between types `A[]` and `A[]`
fail_compilation/test21408.d(19): Error: can't infer return type in function `opEquals`
---
*/

struct A {
    A[] as;
    auto opEquals(A x) {
        return as == x.as;
    }
}

struct B {
    B[] as;
    auto opEquals(B x) {
        return x == this;
    }
}

void main() {}
