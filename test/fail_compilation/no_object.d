/*
DFLAGS:
REQUIRED_ARGS:
TEST_OUTPUT:
---
Error: cannot find source code for runtime library file 'object.d'
       dmd might not be correctly installed. Run 'dmd -man' for installation instructions.
       config file: (null)
import path[0] = fail_compilation
---
*/

// Due to the empty D FLAGS test variable specified above, only the current
// directory is in the import path.  Therefore, compilation fails because the compiler
// cannot locate object.d
