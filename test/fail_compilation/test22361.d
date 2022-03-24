/*
TEST_OUTPUT:
---
fail_compilation/test22361.d(11): Error: unable to read module `this_module_does_not_exist`
fail_compilation/test22361.d(11):        Expected 'this_module_does_not_exist.d' or 'this_module_does_not_exist/package.d' in one of the following import paths:
fail_compilation/test22361.d(11):        [0]: `fail_compilation`
fail_compilation/test22361.d(11):        [1]: `$p:druntime/import$`
fail_compilation/test22361.d(11):        [2]: `$p:phobos$`
---
*/
import this_module_does_not_exist;
