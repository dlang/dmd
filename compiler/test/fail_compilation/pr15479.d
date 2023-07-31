/*
EXTRA_SOURCES: imports/pragma_lib_local.d
RUN_OUTPUT:
---
/usr/bin/ld: pr15479.o: in function `_Dmain':
pr15479.d:(.text._Dmain[_Dmain]+0x5): undefined reference to `lib_get_int'
---
*/
import core.stdc.stdio;
import imports.pragma_lib_local;

void main() {
    printf("%i\n", lib_get_int());
}
