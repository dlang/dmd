/*
TEST_OUTPUT:
----
fail_compilation/enh13855a.d(7): Error: module imports.c314 import 'enh13855a' not found
----
*/
import imports.c314 : bug, enh13855a; // unqualified module would be ambiguous, parsed as symbol
import enh13855a, imports.c314 : bug; // works unchanged
