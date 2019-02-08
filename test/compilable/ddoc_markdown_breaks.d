// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -preview=markdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/++
# Thematic Breaks

Some text before
***
Some text in between
____________________
Some text after

---
This is a code block
---

But this is a thematic break:

- - -

## Not Thematic Breaks

- -
__
**

+/
module ddoc_markdown_lists;
