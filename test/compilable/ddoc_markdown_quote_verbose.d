// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -preview=markdown -transition=vmarkdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/*
TEST_OUTPUT:
----
compilable/ddoc_markdown_quote_verbose.d(17): Ddoc: starting quote block with '> Great, just what I need.. another D in programming. -- Segfault'
----
*/

/++
Quote Block:

> Great, just what I need.. another D in programming. -- Segfault
+/
module test.compilable.ddoc_markdown_code_verbose;
