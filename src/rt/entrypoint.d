/**
 * Contains druntime entry point for console programs.
 *
 * Copyright: Copyright Digital Mars 2000 - 2013.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_entrypoint.d)
 */

module rt.entrypoint;

alias extern(C) int function(char[][] args) MainFunc;

extern (C) int _d_run_main(int argc, char **argv, MainFunc mainFunc);


/***********************************
 * The D main() function supplied by the user's program
 *
 * It always has `_Dmain` symbol name and uses C calling convention.
 * But DMD frontend returns its type as `extern(D)` because of Issue @@@9028@@@.
 * As we need to deal with actual calling convention we have to mark it
 * as `extern(C)` and use its symbol name.
 */
extern(C) int _Dmain(char[][] args);

/***********************************
 * Substitutes for the C main() function.
 * Just calls into d_run_main with the default main function.
 * Applications are free to implement their own
 * main function and call the _d_run_main function
 * themselves with any main function.
 */
extern (C) int main(int argc, char **argv)
{
    return _d_run_main(argc, argv, &_Dmain);
}

version (Solaris) extern (C) int _main(int argc, char** argv)
{
    // This is apparently needed on Solaris because the
    // C tool chain seems to expect the main function
    // to be called _main. It needs both not just one!
    return main(argc, argv);
}


