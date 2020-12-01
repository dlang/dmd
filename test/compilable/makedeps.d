// PERMUTE_ARGS:
// REQUIRED_ARGS: -makedeps=${RESULTS_DIR}/compilable/makedeps.dep -Jcompilable/extra-files -Icompilable/extra-files
// POST_SCRIPT: compilable/extra-files/makedeps.sh

module makedeps;

// Test import statement
import makedeps_a;

// Test import expression
enum text = import("makedeps-import.txt");
static assert(text == "Imported text");

void main()
{
    a_func();
}
