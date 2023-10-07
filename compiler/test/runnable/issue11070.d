/* RUN_OUTPUT:
---
inside switch: 1
---
*/

int get() { return 1; }

void test() {
    import std.stdio : writeln;
    switch (auto x = get()) {
        default:
            writeln("inside switch: ", x);
    }
}

void main() {
    test();
}
