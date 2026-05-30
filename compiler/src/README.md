# DMD's source code

This directory contains the source code of the dmd compiler.
Refer to [this file](dmd/README.md) for an overview of the actual source files.

## Building the compiler

The compiler can be built using the integrated build system `build.d`.

```console
./build.d
```

Building requires a host D compiler (DMD/LDC/GDC) of version 2.079.1 or above
and defaults to `dmd` as found on the path. This behaviour can be overriden
by explicitly specifying a different host compiler using the `HOST_DMD` variable.

```console
./build.d HOST_DMD=<compiler path>
```

Note that building with LDC & GDC requires the `ldmd2`/`gdmd` wrappers to
translate the command line arguments.

See the output of `./build.d --help` to get a list of all supported targets
or see the list of major targets below.

### Prerequisites

To bootstrap `dmd` on posix you need to have a `C++` compiler installed,
such as gcc, when using the default `$CC` setting.

### Bootstrapping

Use `bootstrap.sh` to bootstrap the compiler if there is no D compiler
installed. The script will download an official release and use it
as a host compiler when forwarding targets to `build.d`.

Refer to the `HOST_DMD_VER` variable in `bootstrap.sh` for the currently
used release version.

## Major targets

`build.d` supports a variety of checks for the source which are enforced
alongside of the [general test suite](../test/README.md).

### unittest

Runs all `unittest` blocks in the source code.

### cxx-unittest

Runs the [C++ frontent test](tests/cxxfrontend.cc) to verify the manually
created C++ headers in the source directory.

Note: This is currently not supported on windows.

### cpp-layout-test

Verifies that the manually maintained C++ headers in
[`compiler/include/dmd/`](../include/dmd/) stay in sync with the D
`extern(C++)` declarations in the compiler source. Checks enum constant
values, field offsets and sizes, class instance sizes, vtable indices,
and C++ mangled names.

Note: Linux/64-bit only (Itanium ABI mangling).
