// PERMUTE_ARGS:
// REQUIRED_ARGS: -M -Mf${RESULTS_DIR}/compilable/makedeps2.dep "-Mtmake deps" -Jcompilable/extra-files
// POST_SCRIPT: compilable/extra-files/makedeps2.sh
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
