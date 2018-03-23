// REQUIRED_ARGS: -inline -Icompilable/imports compilable/imports/test9399a

import imports.test9399a;
void fun(int a) {
    void nested() {
        a = 42;
    }
    call!nested();
}
