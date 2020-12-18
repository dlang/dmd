/*
PERMUTE_ARGS:
REQUIRED_ARGS: -lib -makedeps=${TEST_RESULTS}/depfile.dep -Jfail_compilation/extra-files -Ifail_compilation/extra-files
EXTRA_SOURCES: extra-files/makedeps_a.d
TEST_OUTPUT:
---
Error: -makedeps switch is not compatible with multiple objects mode
---
*/
module makedeps_multiobj;

// Test import statement
import makedeps_a;

// Test import expression
enum text = import("makedeps-import.txt");
static assert(text == "Imported text");

void main()
{
    a_func();
}
