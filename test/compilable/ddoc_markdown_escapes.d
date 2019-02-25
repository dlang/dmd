// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -preview=markdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/++
Backslash Escapes:

\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}

But not in code:

---
\{\}
---

`\{\}`

Nor in HTML:

<tag attr="\{\}"></tag>

Nor before things that aren't punctuation:

C:\dlang\dmd
+/
module ddoc_markdown_escapes;
