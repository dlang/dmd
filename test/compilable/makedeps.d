// PERMUTE_ARGS:
// REQUIRED_ARGS: -Md${RESULTS_DIR}/compilable/ -Jcompilable/extra-files
// POST_SCRIPT: compilable/extra-files/makedeps.sh
// EXTRA_SOURCES: /extra-files/makedeps_a.d

module makedeps;

// Test import statement
import makedeps_a;

// Test import expression
enum SH_TEXT = import("makedeps.sh");

void main()
{
    a_func();
}
