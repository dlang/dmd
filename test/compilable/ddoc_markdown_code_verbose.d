// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -preview=markdown -transition=vmarkdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/*
TEST_OUTPUT:
----
compilable/ddoc_markdown_code_verbose.d(19): Ddoc: adding code block for language 'ruby'
----
*/

/++
Code:

``` ruby red
RWBY
```
+/
module test.compilable.ddoc_markdown_code_verbose;
