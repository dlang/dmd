// https://issues.dlang.org/show_bug.cgi?id=19759
/* TEST_OUTPUT:
---
fail_compilation/fail19759.d(10): Error: function `fail19759.fail19759` cannot have parameter of type `float[4]` because its linkage is `extern(C++)`
extern(C++) bool fail19759(float[4] col);
                 ^
fail_compilation/fail19759.d(10):        perhaps use a `float*` type instead
---
*/
extern(C++) bool fail19759(float[4] col);
