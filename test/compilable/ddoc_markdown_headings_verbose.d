// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -transition=markdown -transition=vmarkdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/*
TEST_OUTPUT:
----
compilable/ddoc_markdown_headings_verbose.d(23): Ddoc: added heading 'Heading'
compilable/ddoc_markdown_headings_verbose.d(23): Ddoc: added heading 'Another Heading'
compilable/ddoc_markdown_headings_verbose.d(23): Ddoc: added heading 'And Another'
----
*/

/++
# Heading

Another Heading
===============

And Another
***********
+/
module ddoc_markdown_headings_verbose;
