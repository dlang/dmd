// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh
// EXTRA_SOURCES: extra-files/ddoc_minimal.ddoc

/**
 * Module docs.
 */
module ddoc19974;

/++
Test markdown list followed by code listing.
- test
+/
unittest
{
    // test
}
