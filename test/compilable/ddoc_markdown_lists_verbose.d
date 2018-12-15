// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -transition=markdown -transition=vmarkdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/*
TEST_OUTPUT:
----
compilable/ddoc_markdown_lists_verbose.d(15): Ddoc: starting list item 'list item'
----
*/

/++
- list item
+/
module ddoc_markdown_lists_verbose;
