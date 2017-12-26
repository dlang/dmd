/*
REQUIRED_ARGS: -vcolumns
TEST_OUTPUT:
----
fail_compilation/enh13855b.d(9,47): Error: `;` expected
fail_compilation/enh13855b.d(9,52): Error: no identifier for declarator `c314`
----
*/
import imports.pkg313.c313 : bug, name=imports.c314; // aliased module would require arbitrary lookahead
import name=imports.c314, imports.pkg313.c313 : bug; // works, unchanged
