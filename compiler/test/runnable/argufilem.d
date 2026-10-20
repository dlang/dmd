/*
EXTRA_SOURCES: imports/argufile.d
RUN_OUTPUT:
---
bob is 7 years old
why is 8 scared of 7? because789
---
*/

// NOTE: The bug only works when main.d and argufile.d are put in
//                      separate files and compiled like 'dmd main.d argufile.d'
//                      Also, I'm sure writefln is causing the crash cause when I
//                      use printf(), it doesn't crash.

// main.d -------------------------------------------------------

import argufile;
import core.stdc.stdio : printf;

int main(string[] args)
{
        string message = arguments("bob is ", 7, " years old");

        printf("%.*s\n", cast(int) message.length, message.ptr);

        argufile.useargs(); // will crash here

        return 0;
}
