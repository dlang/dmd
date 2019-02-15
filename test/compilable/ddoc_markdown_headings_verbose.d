// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -preview=markdown -transition=vmarkdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/*
TEST_OUTPUT:
----
compilable/ddoc_markdown_headings_verbose.d(15): Ddoc: added heading 'Heading'
----
*/

/++
# Heading
+/
module ddoc_markdown_headings_verbose;
