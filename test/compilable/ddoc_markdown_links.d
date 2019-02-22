// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -preview=markdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/++
# Links

[unused reference]: https://nowhere.com

A link to [Object].

A link to [the base object][Object].

Not a link because it's an associative array: int[Object].

An inline link to [the D homepage](https://dlang.org).

A reference link to [the **D** homepage][d site].

Not a reference link because it [links to nothing][nonexistent].

A simple link to [dub].

A slightly less simple link to [dub][].

An image: ![D-Man](https://dlang.org/images/d3.png)
Another image: ![D-Man again][dman-error]

[D Site]: https://dlang.org 'D lives here'
[dub]: <https://code.dlang.org>
[dman-error]: https://dlang.org/images/dman-error.jpg
+/
module test.compilable.ddoc_markdown_links;
