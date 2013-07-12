// COMPILER: rdmd
// PERMUTE_ARGS:
// REQUIRED_ARGS: --help
/*
TEST_OUTPUT:
---
Usage: rdmd [RDMD AND DMD OPTIONS]... program [PROGRAM OPTIONS]...
Builds (with dependents) and runs a D program.
Example: rdmd -release myprog --myprogparm 5

Any option to be passed to the compiler must occur before the program name. In
addition to compiler options, rdmd recognizes the following options:
  --build-only      just build the executable, don't run it
  --chatty          write compiler commands to stdout before executing them
  --compiler=comp   use the specified compiler (e.g. gdmd) instead of dmd
  --dry-run         do not compile, just show what commands would be run
                      (implies --chatty)
  --eval=code       evaluate code as in perl -e (multiple --eval allowed)
  --exclude=package exclude a package from the build (multiple --exclude allowed)
  --force           force a rebuild even if apparently not necessary
  --help            this message
  --loop            assume "foreach (line; stdin.byLine()) { ... }" for eval
  --main            add a stub main program to the mix (e.g. for unittesting)
  --makedepend      print dependencies in makefile format and exit
  --man             open web browser on manual page
  --shebang         rdmd is in a shebang line (put as first argument)
---
*/
void main() { }

