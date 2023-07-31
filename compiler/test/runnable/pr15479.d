/*
EXTRA_SOURCES: imports/pragma_lib_local.d
RUN_OUTPUT:
---
42
---
*/
import core.stdc.stdio;
import imports.pragma_lib_local;

void main() {
    printf("%i\n", lib_get_int());
}
