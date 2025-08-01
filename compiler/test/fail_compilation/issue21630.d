/+
TEST_OUTPUT:
---
fail_compilation/issue21630.d(14): Error: cannot use `enum` with a aggregate `foreach`
fail_compilation/issue21630.d(14):        use `static foreach` instead
fail_compilation/issue21630.d(15): Error: cannot use `alias` with a aggregate `foreach`
fail_compilation/issue21630.d(15):        use `static foreach` instead
fail_compilation/issue21630.d(16): Error: cannot use `enum` with a range `foreach`
fail_compilation/issue21630.d(16):        use `static foreach` instead
fail_compilation/issue21630.d(17): Error: cannot use `alias` with a range `foreach`
fail_compilation/issue21630.d(17):        use `static foreach` instead
---
+/

void main()
{
    enum a = [1, 2, 3];
    foreach(enum i; a) { } // error
    foreach(alias i; a) { } // error
    foreach(enum i; 0 .. 3) {  } // error
    foreach(alias i; 0 .. 3) {  } // error
}
