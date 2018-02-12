/*
EXRTRA_SOURCES: imports/wrong_mod_name.d
REQUIRED_ARGS: -Ifail_compilation/imports
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/badimport4.d(10): Error: module `wrong_mod_name_bleh` from file fail_compilation/imports/wrong_mod_name.d must be imported with 'import wrong_mod_name_bleh;'
---
*/
import wrong_mod_name;
