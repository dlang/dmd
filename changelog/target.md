Add `-target=<triple>` for operating system, c, and c++ runtime cross compilation

The command line switch `-target=<triple>` can be used to specify the target the
compiler should produce code for. The format for `<triple>` is `<arch>-[<vendor>-]<os>[-<cenv>[-<cppenv]]`. Specific values of the specifiers are 
shown in the tables below.

`<arch>` 
---------
`<arch>` is an Architecture bitness, optionally followed by instruction set (which duplicates the functionality of the `-mcpu` flag)
| `<arch>`  | Architecture bitness |
| ---------- |-------------| 
| `x86_64`  |  64 bit |
| `x64`        |  64 bit |
| `x86`        |  32 bit |
| `x32`        |  64bit with 32 bit pointers |

| subarch features | equivalent `-mcpu` flag |
| ---------- |-------------| 
| `+sse2`    | `baseline` |
| `+avx`      |  `avx` |
| `+avx2`    |  `avx2` |

The architecture and subarch features are concatenated, so `x86_64+avx2` is 64bit with `avx2` instructions.


`<vendor>` 
---------
`<vendor>` is always ignored, but supported for easier interoperability with other compilers that report and consume target triples.

`<os>`
------

`<os>` is the operating system specifier. It may be optionally followed by a version number as in `darwin20.3.0` or `freebsd12`. For Freebsd, this sets the corresponding predefined `version` identifier, e.g. `freebsd12` sets `version(FreeBSD12)`. For other operating systems this is for easier interoperability with other compilers.

| `<os>` | Operating system | 
| ---------- |-------------| 
| `freestanding` | No operating system |
| `darwin` | MacOS | 
| `dragonfly` | DragonflyBSD | 
| `freebsd` | FreeBSD |
| `openbsd` | OpenBSD | 
| `linux` | Linux |
| `solaris` | Solaris |
| `windows` | Windows |

`<cenv>`
---------
`<cenv>` is the C runtime environment. This specifier is optional. For MacOS the C runtime environment is always assumed to be the system default.

| `<cenv>` | C runtime environment | Default for OS | 
| ---------- |------------- |-------------| 
| `musl` |  musl-libc |        |
| `msvc` |  MSVC runtime  |  Windows  | 
| `bionic` | Andriod libc |         | 
| `digital_mars`|  Digital Mars C runtime for Windows |
|  `glibc` |  GCC C runtime | linux | 
| `newlib` | Newlib Libc |  | 
| `uclibc` |  uclibc |  | 


`<cppenv>`
------------

`<cppenv>` is the C++ runtime environment. This specifier is optional. If this specifier is present the `<cenv>` specifier must also be present.

| `<cppenv>` | C++ runtime environment | Default for OS | 
| ---------- |------------- |-------------| 
| `clang` |  LLVM C++ runtime  |   MacOS, FreeBSD, OpenBSD, DragonflyBSD  |
| `gcc` | GCC  C++ runtime | linux | 
| `msvc` |  MSVC runtime  |  Windows  | 
| `digital_mars`|  Digital Mars C++ runtime for Windows |
| `sun` | Sun C++ runtime | Solaris |
