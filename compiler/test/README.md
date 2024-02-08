Running DMD's test suite
-------------------------

This is the documentation and guide for DMD's test suite. See
[src/README.md](../src/README.md#major-targets) for additional
checks performed alongside these dedicated tests.

Maybe you are looking for the [contributing guide](../CONTRIBUTING.md)
too?

---

- [Quick guide](#quick-guide)
- [Types of Tests](#types-of-tests)
- [`run.d` targets](#rund-targets)
- [Test Configuration](#test-configuration)
- [Environment variables](#environment-variables)
- [Bash Tests](#bash-tests)
- [Test configuration variables](#test-configuration-variables)
- [`TEST_OUTPUT`](#test_output)
- [Test Coding Practices](#test-coding-practices)

---

Quick guide
-----------

### Run all tests

```console
./run.d
```

Note:

- [`run.d`](./run.d) will automatically use all available threads. Use e.g. `-j4` if you need a lower parallelism
- all commands below assume that you are in the `test` directory

### Run only a specific subset

```console
./run.d fail
./run.d compilable
```

As linking is slow the [`runnable`](runnable/README.md) tests take a bit longer to run:

```console
./run.d runnable
```

### Run only an individual test

```console
./run.d fail_compilation/diag10089.d
```

Multiple arguments are supported too.
You can use [`./run.d`](./run.d) to quickly run a custom subset of tests.
For example, all diagnostic tests in [`fail_compilation`](fail_compilation/README.md):

```console
./run.d fail_compilation/diag*.d
```

### Automatically update the `TEST_OUTPUT` segments

Often, when you add a new error message, a few tests need to be updated as their
`TEST_OUTPUT` has changed. This is tedious work and `AUTO_UPDATE` can be to automate it:

```console
AUTO_UPDATE=1 ./run.d fail
```

Updating the `TEST_OUTPUT` can also be done for a custom subset of tests:

```console
./run.d fail_compilation/diag*.d AUTO_UPDATE=1
```

Note:
- you might need to run this command twice if you add a new error message(s) as then the line numbers of the following error messages will change
- `AUTO_UPDATE` doesn't work with tests that have no, empty or multiple `TEST_OUTPUT` segments
- `AUTO_UPDATE` can be set as an environment variable or as Makefile-like argument assignment

### Running the Unit Tests

The unit tests will automatically run when all tests are run using `./run.d`.
To only run the unit tests the `./run.d unit_tests` command can be used.
For a more finer grain control over the unit tests the `./run.d -u` command can
be used:

To run all unit tests:

```console
./run.d -u
```

To only run the unit tests in one or more specific files:

```console
./run.d -u unit/deinitialization.d
```

To only run a subset of the unit tests in a single file:

```console
./run.d -u unit/deinitialization.d --filter Expression
```

In the above example, the `--filter` flag will filter to only run the tests with
a UDA matching the given value, in this case `Expression`.

```d
@("Target.deinitialize")
unittest {}

@("Expression.deinitialize")
unittest {}
```

Of the above unit tests, only the second one will be run, since
`--filter Expression` was specified.

The `--filter` flag works when no files are specified as well.

## Types of Tests

There are two types of tests in the DMD test suite:

* **End-to-end test**. These are tests that invokes the compiler as an external
process in some kind of way. Then it asserts either the exit code or the output
of the compiler. These tests are located in

  - [`compilable`](compilable/README.md)
  - [`fail_compilation`](fail_compilation/README.md)
  - [`runnable`](runnable/README.md)
  - [`runnable_cxx`](runnable_cxx/README.md)
  - [`dshell`](dshell/README.md)

* **Unit tests**. These tests are more of a unit test, integration or
functional style tests. These tests are using the compiler as a library. They
are more flexible because they can assert state internal to the compiler which
the end-to-end tests would never have access to. The unit test runner will
compile all files in the [`unit`](unit/README.md) directory into a single executable and run the
tests. This should make it quick to run the tests since only a single process
need to be started.

`run.d` targets
----------------

    default | all:      run all unit tests that haven't been run yet

    run_tests:          run all tests
    run_runnable_tests:         run just the runnable tests
    run_compilable_tests:       run just the compilable tests
    run_fail_compilation_tests: run just the fail compilation tests
    unit_test:                  run all unit tests (those in the "unit" directory)

    quick:              run all tests with no default permuted args
                        (individual test specified options still honored)

    clean:              remove all temporary or result files from previous runs

    test_results/compilable/json.d.out      runs an individual test
                                            (run log of the test is stored)

Test Configuration
------------------

All tests defined within `.d` source files may use various settings to configure how they are to be run, i.e.

`compilable/hellotest.d`:
```d
/*
REQUIRED_ARGS: -version=Foo
TEST_OUTPUT:
---
Hello, World!
---
*/
void main(string[] args)
{
    version(Foo)
    {
        pragma(msg, "Hello World");
    }
}
```

Test parameters can be restricted to certain targets by adding a brace-enclosed
condition after the name, i.e. `REQUIRED_ARGS(<condition>): ...`. The `<condition>`
consists of the target operating system followed by an optional model suffix,
e.g. `linux`, `win32mscoff`, `freebsd64`.

Valid platforms:
- win
- linux
- osx
- freebsd
- dragonflybsd
- netbsd

Valid models:
- 32
- 32mscoff  (windows only)
- 32omf  (windows only)
- 64

Note that test parameters *MUST* be followed by a colon (intermediate whitespace is allowed).
The test runner will issue an error for a missing colon (e.g. `REQUIRED_ARGS foo`)
to avoid ambiguities. Test directives embedded within other words (e.g. `OPTLINK`)
will be ignored.

The following is a list of all available settings:

    ARG_SETS:            sets off extra arguments to invoke $(DMD) with (seperated by ';').
                         default: (none)

    COMPILE_SEPARATELY:  if present, forces each .d file to compile separately and linked
                         together in an extra setup. May specify additional parameters which
                         are passed to $(DMD) when linking the generated object files.
                         default: (none, aka compile/link all in one step)

    COMPILED_IMPORTS:    list of modules files that are imported by the main source file that
                         should be included in compilation; this differs from the EXTRA_SOURCES
                         variable in that these files could be compiled by either explicitly
                         passing them to the compiler or by using the "-i" option. Using this
                         option will cause the test to be compiled twice, once using "-i" and
                         once by explicitly passing the modules to the compiler.
                         default: (none)

    CXXFLAGS:            list of extra arguments passed to $(CC) when compiling C++ sources
                         defined in EXTRA_CPP_SOURCES.
                         default: (none)

    DFLAGS:              Overrides the DFLAGS environment variable if specified in the test.
                         No values are permitted; an error will be emitted if the value is not
                         empty.

    DISABLED:            selectively disable the test on specific platforms (if empty, the test is
                         considered to be enabled on all platform). Target platforms are specified
                         using nearly the same syntax as conditions of optional parameters, except for
                         `win` instead of `windows`.
                         Potential filters are `win32`, `linux`, ...
                         default: (none, enabled)

    EXECUTE_ARGS:        parameters to add to the execution of the test
                         default: (none)

    EXTRA_CPP_SOURCES:   list of extra C++ files to build and link along with the test
                         default: (none).

    EXTRA_FILES:         list of extra files and sources used by the test, either during
                         compilation or execution of the test. It is currently ignored by the test
                         runner, but serves as documentation of the test itself.
                         default: (none)

    EXTRA_OBJC_SOURCES:  list of extra Objective-C files to build and link along with the test
                         default: (none). Test files with this variable will be ignored unless
                         the D_OBJC environment variable is set to "1"

    EXTRA_SOURCES:       list of extra files to build and link along with the test
                         default: (none)

    GDB_MATCH:           a regular expression describing the expected output of GDB_SCRIPT. The test
                         will fail if it does not match the actual output.
                         default: (none)

    GDB_SCRIPT:          if present, starts a `gdb` session for the compiled executable to run the commands
                         specified in the corresponding section. GDB_MATCH may be used to used to verfiy
                         expected output using a regex.
                         note: restricted to `runnable` tests, the executable will not be run outside of the
                               gdb session.
                         default: (none)

    LINK:                enables linking (used for the compilable and fail_compilable tests).
                         default: (none)

    OUTPUT_FILES:       files generated during the compilation (separated by ';').
                        The content of each file is appended to the output of the
                        compilation (in the order of this list) according to the HAR
                        format (https://code.dlang.org/packages/har).
                        Example:
                        ------------------------------------------
                        <Compilation Output>
                        === <FILENAME_1>
                        <CONTENT_1>
                        === <FILENAME_2>
                        <CONTENT_2>
                        [...]
                        ------------------------------------------
                        The merged output will then be prepared and compared to the
                        expected TEST_OUTPUT as defined below.
                        default: (none)

    PERMUTE_ARGS:        the set of arguments to permute in multiple $(DMD) invocations.
                         An empty set means only one permutation with no arguments.
                         default: the make variable ARGS (see below)

    POST_SCRIPT:         name of script to execute after test run
                         note: arguments to the script may be included after the name.
                               additionally, the name of the file that contains the output
                               of the compile/link/run steps is added as the last parameter.
                         default: (none)

    REQUIRED_ARGS:       arguments to add to the $(DMD) command line
                         default: (none)
                         note: the make variable REQUIRED_ARGS is also added to the $(DMD)
                               command line (see below)

    RUN_OUTPUT:         output expected from running the compiled executable which must match
                        the actual output. The comparison adheres to the rules defined for
                        TEST_OUTPUT and allow e.g. using special sequences as defined below.

    TEST_OUTPUT:         the output is expected from the compilation (if the
                         output of the compilation doesn't match, the test
                         fails). You can use the this format for multi-line
                         output:
                         TEST_OUTPUT:
                         ---
                         Some
                         Output
                         ---
                         note: if not given, it is assumed that the compilation will be silent.
                         default: (none)

    TEST_OUTPUT_FILE:   file containing the expected output as defined for TEST_OUTPUT.
                        note: Further TEST_OUTPUT sections in the test are ignored.
                        default: (none)

    TRANSFORM_OUTPUT:   steps to apply to the output of the compilation before it
                        is compared to the expected TEST_OUTPUT. A step may take
                        arguments akin to a function call, e.g. `step(arg)` and arguments
                        may be quoted using "".

                        Supported transformations:
                        - sanitize_json:    Remove compiler specific information from output
                                            of -Xi (see test/tools/sanitize_json.d)
                                            arguments: none

                        - remove_lines:     Remove lines matching a given regex
                                            arguments: the regex
                                            note: patterns containing ')' must be quoted

    UNICODE_NAMES:      file containing symbols with unicode characters in their name, which might
                        not be supported on some specific platforms. It is currently ignored by the
                        test runner, but serves as documentation of the test itself.
                        default: (none)


Environment variables
------------------------------

[`run.d`](./run.d) uses environment variables to store test settings and as a way to pass these settings to the test wrapper tool [`d_do_test.d`](tools/d_do_test.d).

> Note: These variables are also available inside any Bash test.

    ARGS:          set to execute all combinations of
    AUTO_UPDATE:   set to 1 to auto-update mismatching test output
    CC:            C++ compiler to use, ex: dmc, g++
    DMD:           compiler to use, ex: ../src/dmd (required)
    MODEL:         32 or 64 (required)
    OS:            windows, linux, freebsd, osx, netbsd, dragonflybsd
    REQUIRED_ARGS: arguments always passed to the compiler
    RESULTS_DIR:   base directory for test results

Windows vs non-windows portability env vars:

    DSEP:          \\ or /
    EXE:          .exe or <null> (required)
    OBJ:          .obj or .o (required)
    SEP:           \ or / (required)

Bash Tests
----------

Along with the environment variables provided by [`run.d`](./run.d) (see above), an additional set of environment variables are made available to Bash tests. These variables are defined in `tools/exported_vars.sh`:

    EXTRA_FILES        directory for extra files of this test type, e.g. runnable/extra-files

    LIBEXT             platform-specific extension for library files, e.g. .a or .lib

    RESULTS_TEST_DIR   the results directory for tests of this type, e.g. test_results/runnable

    OUTPUT_BASE        the prefix used for test output files, e.g. test_results/runnable/mytest

    SOEXT              platform-specific extension for shared object files (aka. dynamic libraries),
                       e.g. .so, .dll or .dylib

    TEST_DIR           the name of the test directory
                       (one of compilable, fail_compilation or runnable)

    TEST_NAME          the base name of the test file without the extension, e.g. test15897

Test configuration variables
----------------------------

Sometimes test configuration arguments must be dynamic.
For example, the output of all tests should be placed into `RESULTS_DIR`:

```
// REQUIRED_ARGS: -mixin=${RESULTS_DIR}/fail_compilation/mixin_test.mixin
```

Currently these variables are exposed:

    RESULTS_DIR       Path to `test_results`

`TEST_OUTPUT`
-------------

A few operations are done on the output of a test before the comparison with `TEST_OUTPUT`:

- newlines get unified for consistent `TEST_OUTPUT` between platforms
- DMD's debug message (e.g. `DMD v2.084.0-255-g86b608a15-dirty DEBUG`) gets stripped away
- paths to `test_results` will be replaced with `{{RESULTS_DIR}}`

`TEST_OUTPUT` offers the following special sequences to match error messages which
depend on the current platform and target:

    $n$             arbitrary amount of digits

    $p:<tail>$      paths ending with <tail> (which must refer to an existing file or directory)

    $?:<choices>$   selection based on the current environment where a choice is either
                    conditional `<condition>=<content>` or a fallback value `<default>`.
                    Multiple choices are separated by `|` and the leftmost satisfied condition
                    or fallback is chosen if multiple choices apply.

                    Supported conditions:
                    - OS: posix, windows, ...
                    - Model: 64, 32mscoff, 32omf and 32 (also matches 32mscoff + 32omf)

    $r:<regex>$     any text matching <regex> (using $ inside of <regex> is not
                    supported, use multiple regexes instead)

Both stderr and stdout of the DMD are captured for output comparison.

## Test Coding Practices

The purpose of the test suite is to test the compiler only. This means:

* do not import modules from Phobos
* keep imports from druntime to the interface to the C standard library
* use `core.stdc.stdio.printf`, not `std.stdio.writef`

In order to make the test suite run faster, multiple unrelated tests can
be aggregated into a single file, for example `test/runnable/test42.d`

Each test should be in the following form:

```d
/*******************************/
// https://issues.dlang.org/show_bug.cgi?id=NNNN

void testNNNN()
{
}
```

The NNNN is the bugzilla issue number this test ensures is fixed.
The test code should be self-contained. The test code should be
minimized to focus on the test.

As usual, test source code should be LF terminated lines, and not
contain any tab characters.
