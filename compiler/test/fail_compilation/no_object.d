/*
DFLAGS:
TEST_OUTPUT:
---
Error: `object` not found. object.d may be incorrectly installed or corrupt.
       dmd might not be correctly installed. Run 'dmd -man' for installation instructions.
       config file: not found
---
*/

// Due to the empty D FLAGS test variable specified above, only the current
// directory is in the import path.  Therefore, compilation fails because the compiler
// cannot locate object.d
