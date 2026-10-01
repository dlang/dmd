import ti_emission_declarations;

int referenceTIs()() {
    auto ti_S = typeid(S);
    auto ti_C = typeid(C); // TypeInfo_Class: never lazily emitted
    auto ti_const_C = typeid(const C);
    auto ti_I = typeid(I);
    auto ti_E = typeid(E);

    return 123;
}

version (Reference_for_CTFE_only) {
    // expected: no TypeInfo definitions in this object file
    static assert(referenceTIs() == 123);
} else {
    // expected: 4 lazy TypeInfo definitions
    void foo() { referenceTIs(); }
}
