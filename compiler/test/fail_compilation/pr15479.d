/*
LINK:
EXTRA_SOURCES: imports/pragma_lib_local.d
TEST_OUTPUT:
---
/usr/bin/ld: cannot find {{RESULTS_DIR}}/fail_compilation/imports/extra-files/local_lib.a: No such file or directory
collect2: error: ld returned 1 exit status
Error: linker exited with status 1
---
*/
import core.stdc.stdio;
import imports.pragma_lib_local;

void main() {
    printf("%i\n", lib_get_int());
}
