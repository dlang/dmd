// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -preview=markdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/++
# Links

[D Site]: https://dlang.org 'D lives here'
[unused reference]: https://nowhere.com

A link to [partition].

A link to [the base object][Object].

Not a link because it's an associative array: int[Object].

An inline link to [the D homepage](https://dlang.org).

A reference link to [the **D** homepage][d site].

Not a reference link because it [links to nothing][nonexistent].

A simple link to [dub].

A slightly less simple link to [dub][].

An image: ![D-Man](https://dlang.org/images/d3.png)
Another image: ![D-Man again][dman-error]

[dub]: <https://code.dlang.org>
[dman-error]: https://dlang.org/images/dman-error.jpg

$(P
    [tour]: https://tour.dlang.org

    Here's a [reference to the tour][tour] inside a macro.
)
+/
module test.compilable.ddoc_markdown_links;

import std.algorithm.sorting;
