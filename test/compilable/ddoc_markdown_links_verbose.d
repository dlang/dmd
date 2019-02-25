// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -preview=markdown -transition=vmarkdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/*
TEST_OUTPUT:
----
compilable/ddoc_markdown_links_verbose.d(28): Ddoc: found link reference 'dub' to 'https://code.dlang.org'
compilable/ddoc_markdown_links_verbose.d(28): Ddoc: linking '[Object]' to '$(DOC_ROOT_object)object$(DOC_EXTENSION)#.Object'
compilable/ddoc_markdown_links_verbose.d(28): Ddoc: linking '[the D homepage](https://dlang.org)' to 'https://dlang.org'
compilable/ddoc_markdown_links_verbose.d(28): Ddoc: linking '[dub]' to 'https://code.dlang.org'
compilable/ddoc_markdown_links_verbose.d(28): Ddoc: linking '[dub][]' to 'https://code.dlang.org'
compilable/ddoc_markdown_links_verbose.d(28): Ddoc: linking '![D-Man](https://dlang.org/images/d3.png)' to 'https://dlang.org/images/d3.png'
----
*/

/++
Links:

A link to [Object].
An inline link to [the D homepage](https://dlang.org).
A simple link to [dub].
A slightly less simple link to [dub][].
An image: ![D-Man](https://dlang.org/images/d3.png)

[dub]: https://code.dlang.org
+/
module test.compilable.ddoc_markdown_links_verbose;
