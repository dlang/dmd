/*
DFLAGS:
TEST_OUTPUT:
---
Error: cannot find source code for runtime library file `object.d`.
       DMD might not be correctly installed. Run 'dmd -man' for installation instructions.
       There is no config file. Perhaps add one or add an include path using `-I`.
       Currently, the compiler search on the following include paths:
       [0]: `fail_compilation`
---
*/

// Due to the empty D FLAGS test variable specified above, only the current
// directory is in the import path.  Therefore, compilation fails because the compiler
// cannot locate object.d
