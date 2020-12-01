/*
PERMUTE_ARGS:
REQUIRED_ARGS: -makedeps= -Jcompilable/extra-files -Icompilable/extra-files
TEST_OUTPUT:
---
Error: expected filename after -makedeps=
       run `dmd` to print the compiler manual
       run `dmd -man` to open browser on manual
---
*/
module makedeps_nofile;

// Test import statement
import makedeps_a;

// Test import expression
enum text = import("makedeps-import.txt");
static assert(text == "Imported text");

void main()
{
    a_func();
}
