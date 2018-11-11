// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -wi -o- -transition=markdown -transition=vmarkdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/*
TEST_OUTPUT:
----
compilable/ddoc_markdown_emphasis_verbose.d(20): Ddoc: emphasized text 'emphasized text'
compilable/ddoc_markdown_emphasis_verbose.d(20): Ddoc: emphasized text 'strongly emphasized text'
----
*/

/++
Markdown Emphasis:

*emphasized text*

**strongly emphasized text**
+/
module ddoc_markdown_emphasis;
