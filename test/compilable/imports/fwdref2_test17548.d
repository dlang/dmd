module imports.fwdref2_test17548;

import test17548;

struct S2 {
    void bar(int arg = .test17548.cnst) {}
    S1 s;
    import imports.fwdref2_test17548;
}
