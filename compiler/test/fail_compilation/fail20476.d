// https://issues.dlang.org/show_bug.cgi?id=24632
// EXTRA_SOURCES: imports/fail20476/bug/buggier/package.d imports/fail20476/bug/other/package.d
/*
TEST_OUTPUT:
---
fail_compilation/imports/fail20476/bug/other/package.d(3): Error: undefined identifier `buggier` in package `bug`, perhaps add `static import bug.buggier;`
---
*/

module fail20476;
