// REQUIRED_ARGS: -HCf=${RESULTS_DIR}/compilable/dtoh_VarDeclaration.out -c
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/dtoh-postscript.sh

/*
TEST_OUTPUT:
---
---
*/

int x = 42;

extern int y;

extern (C) int z;

extern (C++) __gshared int t;

extern (C) struct S;

extern (C++) struct S2;

extern (C) class C;

extern (C++) class C2;

extern (C) union U;

extern (C++) union U2;
