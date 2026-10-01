// https://github.com/dlang/dmd/issues/22543

enum int[string] aa = [
    "a": 42,
];

int i = aa["a"];

void foo() {
    static int j = aa["a"];
}
