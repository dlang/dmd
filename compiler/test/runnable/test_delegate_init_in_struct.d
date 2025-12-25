struct S {
    string[] delegate() dg;
    string[] bla;
}

S s = {
    dg: () => ["hello"], // SEGFAULT without explicit `delegate`
    bla: ["blub"],
};

void main() {
    auto result = s.dg();
    assert(result.length == 1);
    assert(result[0] == "hello");
}

