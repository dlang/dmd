/**
TEST_OUTPUT:
---
fail_compilation/diag_debug_conditional.d(15): Error: identifier or integer expected inside `debug(...)`, not `alias`
debug(alias)
      ^
fail_compilation/diag_debug_conditional.d(16): Error: identifier or integer expected inside `version(...)`, not `alias`
version(alias)
        ^
fail_compilation/diag_debug_conditional.d(17): Error: declaration expected following attribute, not end of file
---
 */

// Line 1 starts here
debug(alias)
version(alias)
