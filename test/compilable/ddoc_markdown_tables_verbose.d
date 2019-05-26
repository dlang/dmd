// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -preview=markdown -transition=vmarkdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/*
TEST_OUTPUT:
----
compilable/ddoc_markdown_tables_verbose.d(19): Ddoc: formatting table '| this | that |'
----
*/

/++
Table:

| this | that |
| ---- | ---- |
| cell | cell |
+/
module test.compilable.ddoc_markdown_tables_verbose;
