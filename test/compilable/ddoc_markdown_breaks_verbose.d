// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -wi -o- -preview=markdown -transition=vmarkdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/*
TEST_OUTPUT:
----
compilable/ddoc_markdown_breaks_verbose.d(21): Ddoc: converted '___' to a thematic break
compilable/ddoc_markdown_breaks_verbose.d(21): Ddoc: converted '- - -' to a thematic break
compilable/ddoc_markdown_breaks_verbose.d(21): Ddoc: converted '***' to a thematic break
----
*/

/++
Thematic Breaks

___
- - -
***
+/
module ddoc_markdown_breaks;
