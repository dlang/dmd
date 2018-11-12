// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o- -transition=markdown
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

/++
# ATX-Style Headings

# H1
## H2
### H3
#### H4
##### H5
###### H6

 ### headings
  ## with initial
   # spaces

## heading with *emphasis*

## heading with trailing `#`'s #######
## heading with trailing literal ##'s
## heading with another trailing literal#
## heading with backslash-escaped trailing #\##

## Some empty headers:
##
#
### ###

Setext-Style Headings
=====================

H1
==
$(P
H1
=

H2
**
)

Multi-*line
heading*
***

heading with initial spaces
   ***
and text directly after


# Not Headings

#hashtag not a heading because there's no space after the `#`

####### Not a heading because it has more than 6 `#`'s

\## Not a heading because of the preceeding backslash

Not a heading because of spaces within
= =

Not a heading because of spaces within
*** *

Not a heading because backslash-escaped
\***

+/
module ddoc_markdown_headings;
