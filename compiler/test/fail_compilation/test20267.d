/*
EXTRA_FILES: imports/test20267.d
TEST_OUTPUT:
---
fail_compilation/test20267.d(34): Error: variable `string` is used as a type
    string[] args2 = args;
             ^
fail_compilation/test20267.d(33):        variable `string` is declared here
    immutable string = "bar";
              ^
fail_compilation/test20267.d(37): Error: variable `boolean` is used as a type
    boolean b = false;
            ^
fail_compilation/test20267.d(36):        variable `boolean` is declared here
    bool boolean = true;
         ^
fail_compilation/test20267.d(44): Error: variable `array` is used as a type
    array foo;
          ^
fail_compilation/test20267.d(42):        variable `array` is imported here from: `imports.test20267`
    import imports.test20267 : array;
           ^
fail_compilation/imports/test20267.d(3):        variable `array` is declared here
int[1] array;
       ^
---
*/

alias boolean = bool;

void foo(string[] args)
{
    immutable string = "bar";
    string[] args2 = args;

    bool boolean = true;
    boolean b = false;
}

void bar()
{
    import imports.test20267 : array;

    array foo;
}
