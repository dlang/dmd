/*
REQUIRED_ARGS: -Icompilable/imports
PERMUTE_ARGS:
TEST_OUTPUT:
---
compilable/badimport2.d(9): Deprecation: module `wrong_mod_name_bleh` from file compilable/imports/wrong_mod_name.d must be imported with 'import wrong_mod_name_bleh;'
---
*/
import wrong_mod_name;
