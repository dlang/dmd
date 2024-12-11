/*
TEST_OUTPUT:
---
fail_compilation/fail351.d(16): Error: expression `this.num[index]` of type `immutable(uint)` is not implicitly convertible to return type `ref uint`
        return num[index];
                  ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=2780

struct Immutable {
    immutable uint[2] num;

    ref uint opIndex(size_t index) immutable return {
        return num[index];
    }
}

void main() {
    immutable Immutable foo;
    //foo[0]++;
}
