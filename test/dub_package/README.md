DMD as a library
================

The tests in this module are high-level and mostly indented to make sure all
necessary modules are included in the Dub package.

The tests are executable single-file packages for the D's package manager `dub`
and can be directly executed:

```bash
./lexer.d
```

If you want to see the log output or want to pass additional options, use `--single`:

```bash
dub --single -v lexer.d
```

If you don't have `dub` installed on your system,
[install an official release](https://dlang.org/download.html).
