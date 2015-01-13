// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh backticks

module ddocbackticks;

/// This should produce `inline code`.
void test() {}

/// But `this should NOT be inline'
///
/// However, restarting on a new line should be `inline again`.
void test2() {}
