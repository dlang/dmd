Running DMD's test suite
-------------------------

This is the documentation and guide for DMD's test suite.
Maybe you are looking for the [contributing guide](../CONTRIBUTING.md) too?

Quick guide
-----------

### Run all tests

```sh
make -j10
```

Note:

- the exact parallelism parameter `-j` depends on your system,
but if you have enough memory, a high `-j` allows a significant speed-up.
- all commands below assume that you are in the `test` directory

### Run only a specific subset

```sh
make -j10 run_fail_compilation_tests
make -j10 run_compilable_tests
```

As linking is slow the `runnable` tests take a bit longer:

```sh
make -j10 run_runnable_tests
```

### Run only an individual test

```sh
./run_individual_tests fail_compilation/diag10089.d
```

Multiple arguments are supported too.
You can use `./run_individual_tests` to quickly run a custom subset of tests.
For example, all diagnostic tests in `fail_compilation`:

```sh
./run_individual_tests fail_compilation/diag*.d
```

### Automatically update the `TEST_OUTPUT` segments

Often, when you add a new error message, a few tests need to be updated as their
`TEST_OUTPUT` has changed. This is tedious work and `AUTO_UPDATE` can be to automate it:

```sh
AUTO_UPDATE=1 make run_fail_compilation_tests -j10
```

Updating the `TEST_OUTPUT` can also be done for a custom subset of tests:

```sh
AUTO_UPDATE=1 ./run_individual_tests fail_compilation/diag*.d
```

Note:
- you might need to run this command twice if you add a new error message(s) as then the line numbers of the following error messages will change
- `AUTO_UPDATE` doesn't work with tests that have multiple `TEST_OUTPUT` segments

Makefile targets
----------------

    default | all:      run all unit tests that haven't been run yet

    run_tests:          run all tests
    run_runnable_tests:         run just the runnable tests
    run_compilable_tests:       run just the compilable tests
    run_fail_compilation_tests: run just the fail compilation tests

    quick:              run all tests with no default permuted args
                        (individual test specified options still honored)

    clean:              remove all temporary or result files from previous runs

    test_results/compilable/json.d.out      runs an individual test
                                            (run log of the test is stored)

Test Configuration
------------------

All tests defined within `.d` source files may use various settings to configure how they are to be run, i.e.

`runnable/hellotest.d`:
```D
/*
REQUIRED_ARGS: -version=Foo
TEST_OUTPUT:
---
Hello, World!
---
*/
import std.stdio;
void main(string[] args)
{
    version(Foo)
    {
        writeln("Hello, World!");
    }
}
```

The following is a list of all available settings:

    COMPILE_SEPARATELY:  if present, forces each .d file to compile separately and linked
                         together in an extra setup.
                         default: (none, aka compile/link all in one step)

    EXECUTE_ARGS:        parameters to add to the execution of the test
                         default: (none)

    COMPILED_IMPORTS:    list of modules files that are imported by the main source file that
                         should be included in compilation; this differs from the EXTRA_SOURCES
                         variable in that these files could be compiled by either explicitly
                         passing them to the compiler or by using the "-i" option. Using this
                         option will cause the test to be compiled twice, once using "-i" and
                         once by explicitly passing the modules to the compiler.
                         default: (none)

    DFLAGS:              Overrides the DFLAGS environment variable if specified in the test.
                         No values are permitted; an error will be emitted if the value is not
                         empty.

    EXTRA_SOURCES:       list of extra files to build and link along with the test
                         default: (none)

    EXTRA_OBJC_SOURCES:  list of extra Objective-C files to build and link along with the test
                         default: (none). Test files with this variable will be ignored unless
                         the D_OBJC environment variable is set to "1"

    PERMUTE_ARGS:        the set of arguments to permute in multiple $(DMD) invocations.
                         An empty set means only one permutation with no arguments.
                         default: the make variable ARGS (see below)

    ARG_SETS:            sets off extra arguments to invoke $(DMD) with (seperated by ';').
                         default: (none)

    LINK:                enables linking (used for the compilable and fail_compilable tests).
                         default: (none)

    TEST_OUTPUT:         the output is expected from the compilation (if the
                         output of the compilation doesn't match, the test
                         fails). You can use the this format for multi-line
                         output:
                         TEST_OUTPUT:
                         ---
                         Some
                         Output
                         ---

    POST_SCRIPT:         name of script to execute after test run
                         note: arguments to the script may be included after the name.
                               additionally, the name of the file that contains the output
                               of the compile/link/run steps is added as the last parameter.
                         default: (none)

    REQUIRED_ARGS:       arguments to add to the $(DMD) command line
                         default: (none)
                         note: the make variable REQUIRED_ARGS is also added to the $(DMD)
                               command line (see below)

    DISABLED:            selectively disable the test on specific platforms (if empty, the test is
                         considered to be enabled on all platform).
                         default: (none, enabled)
                         Valid platforms: win linux osx freebsd dragonflybsd netbsd
                         Optionally a MODEL suffix can used for further filtering, e.g.
                         win32 win64 linux32 linux64 osx32 osx64 freebsd32 freebsd64

Makefile Environment variables
------------------------------

The Makefile uses environment variables to store test settings and as a way to pass these settings to the test wrapper tool `d_do_test`.

> Note: These variables are also available inside any Bash test.

    ARGS:          set to execute all combinations of
    REQUIRED_ARGS: arguments always passed to the compiler
    DMD:           compiler to use, ex: ../src/dmd (required)
    CC:            C++ compiler to use, ex: dmc, g++
    OS:            win32, win64, linux, freebsd, osx, netbsd, dragonflybsd
    RESULTS_DIR:   base directory for test results
    MODEL:         32 or 64 (required)
    AUTO_UPDATE:   set to 1 to auto-update mismatching test output

Windows vs non-windows portability env vars:

    DSEP:          \\ or /
    SEP:           \ or / (required)
    OBJ:          .obj or .o (required)
    EXE:          .exe or <null> (required)

Bash Tests
----------

Along with the environment variables provided by the Makefile (see above), an additional set of environment variables are made available to Bash tests. These variables are defined in `tools/exported_vars.sh`:

    TEST_DIR           the name of the test directory
                       (one of compilable, fail_compilation or runnable)

    TEST_NAME          the base name of the test file without the extension, e.g. test15897

    RESULTS_TEST_DIR   the results directory for tests of this type, e.g. test_results/runnable

    OUTPUT_BASE        the prefix used for test output files, e.g. test_results/runnable/mytest

    EXTRA_FILES        directory for extra files of this test type, e.g. runnable/extra-files

    LIBEXT             platform-specific extension for library files, e.g. .a or .lib
