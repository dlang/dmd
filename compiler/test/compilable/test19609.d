// https://issues.dlang.org/show_bug.cgi?id=19609
// EXTRA_FILES: imports/test19609a.d imports/test19609b.d imports/test19609c.d
/*
TEST_OUTPUT:
---
compilable/test19609.d(17): Deprecation: module `imports.test19609a` is deprecated
import imports.test19609a;
       ^
compilable/test19609.d(18): Deprecation: module `imports.test19609b` is deprecated - hello
import imports.test19609b;
       ^
compilable/test19609.d(19): Deprecation: module `imports.test19609c` is deprecated
import imports.test19609c;
       ^
---
*/
import imports.test19609a;
import imports.test19609b;
import imports.test19609c;
