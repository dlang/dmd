/*
PERMUTE_ARGS:
REQUIRED_ARGS: -makedeps=${RESULTS_DIR}/compilable/makedeps.dep -makedeps=other-file.dep -Jcompilable/extra-files -Icompilable/extra-files
TEST_OUTPUT:
---
Error: -makedeps[=file] can only be provided once!
       run `dmd` to print the compiler manual
       run `dmd -man` to open browser on manual
---
*/
module makedeps_doubleparam;

// Test import statement
import makedeps_a;

// Test import expression
enum text = import("makedeps-import.txt");
static assert(text == "Imported text\x0a");

void main()
{
    a_func();
}
