/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/issue22229.d(13): Error: returning scope variable esult is not allowed in a @safe function
fail_compilation/issue22229.d(12):        esult inferred scope because of esult = s.buf[0..3]
fail_compilation/issue22229.d(20): Error: returning scope variable esult is not allowed in a @safe function
fail_compilation/issue22229.d(19):        esult inferred scope because of esult = s.p
---
*/
@safe:

struct S {  char[] buf; char* p; }

char[] def3(scope return ref S s) {
    auto result = s.buf[0..3];
    return result; // should produce error
}

/***********************************/

char* ghi3(scope return ref S s) {
    auto result = s.p;
    return result; // should produce error
}
