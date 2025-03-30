/*
PERMUTE_ARGS:
REQUIRED_ARGS: -makedepsbla -Jcompilable/extra-files -Icompilable/extra-files
TEST_OUTPUT:
---
Error: unrecognized switch '-makedepsbla'
       run `dmd` to print the compiler manual
       run `dmd -man` to open browser on manual
---
*/
module makedeps_wrongflag;

// Test import statement
import makedeps_a;

// Test import expression
enum text = import("makedeps-import.txt");
static assert(text == "Imported text\x0a");

void main()
{
    a_func();
}
