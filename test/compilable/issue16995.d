// COMPILED_IMPORTS: imports/module_with_tests.d
// REQUIRED_ARGS: -unittest
// COMPILE_SEPARATELY


import imports.module_with_tests;

void main() {
    import module_with_tests;
    foreach(ut; __traits(getUnitTests, module_with_tests)) {
        ut();
    }
}
