// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -preview=markdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/*
TEST_OUTPUT:
----
----
*/

/++
# Tables

| Rounding mode | rndint(4.5) | rndint(5.5) | rndint(-4.5) | Notes |
| ------------- | ----------: | ----------: | -----------: | ----- |
| Round to nearest | 4 | 6 | -4 | Ties round to an even number |
| Round down | 4 | 5 | -5 | &nbsp; |
| Round up | 5 | 6 | -4 | &nbsp; |
| Round to zero | 4 | 5 | -4 | &nbsp; |

    this|that
    ----|----
    cell|cell<br>sell

| abc | def |
| --- | --- |
| bar |
| *bar* | baz | boo |

> | quote |
> | ----- |
> | table |

* | list |
  | ---- |
  | table |

| default | left | center | right |
| --- | :-- | :--: | --: |

Look Ma, a table without a body!

| not | a | table |
| -- |
| wrong number of header columns |
+/
module test.compilable.ddoc_markdown_tables;
