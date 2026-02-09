// https://github.com/dlang/dmd/issues/22544

struct S {
    int bar() { return 1; }
}

void foo(string key) {
    int[string] aa;
    with (S())
        aa[key] = bar();
}
