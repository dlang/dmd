// REQUIRED_ARGS: -de -v
// PERMUTE_ARGS:
// CAPTURE_OUTPUT: stderr
/*
TEST_OUTPUT:
---
compilable/test9960.d(13): Deprecation: constructor test9960.D.this is deprecated
compilable/test9960.d(13): Deprecation: constructor test9960.D.this is deprecated
---
*/

class D { deprecated this(){} }
T func(T)() if (is(typeof(new T()))) { return null; }
int main() {
    enum res1 = is(typeof(func!D()));
    return res1;
}
