// EXTRA_SOURCES:
// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 12745

/**
i underlined $(BR)
_i not underlined $(BR)
__i force underscore $(BR)
$(BR)
_0 not underscored $(BR)
__0 force underscored

Underscores:
1_1 $(BR)
1_a $(BR)
a_1 $(BR)
a_a $(BR)
*/
int i;