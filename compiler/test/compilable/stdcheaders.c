/* Do a smoke test of the C Standard headers.
 * Many platforms do not support all the C Standard headers.
 */

#include <assert.h>

#include <complex.h>

#include <ctype.h>
#include <errno.h>

#ifndef _MSC_VER // C:\Program Files (x86)\Windows Kits\10\include\10.0.22621.0\ucrt\fenv.h(68): Error: variable `stdcheaders._Fenv1` extern symbols cannot have initializers
#include <fenv.h>
#endif

#include <float.h>
#include <inttypes.h>
#include <iso646.h>
#include <limits.h>
#include <locale.h>

#ifndef __APPLE__ // /Applications/Xcode-14.2.0.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/tgmath.h(39): Error: named parameter required before `...`
#include <math.h>
#ifndef _MSC_VER // C:\Program Files (x86)\Windows Kits\10\include\10.0.26100.0\ucrt\corecrt_math.h(93): Error: reinterpretation through overlapped field `f` is not allowed in CTFE
float x = NAN;
#endif
#endif

#ifndef _MSC_VER // setjmp.h(51): Error: missing tag `identifier` after `struct
#include <setjmp.h>
#endif

#if !(defined(__linux__) && defined(__aarch64__)) // /usr/include/linux/types.h(12): Error: __int128 not supported
#include <signal.h>
#endif

#include <stdalign.h>

#include <stdarg.h>

#ifndef __linux__
#ifndef _MSC_VER
#ifndef __APPLE__ // /Applications/Xcode-14.2.0.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/14.0.0/include/stdatomic.h(80): Error: type-specifier is missing
#include <stdatomic.h>
#endif
#endif
#endif

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#ifndef _MSC_VER // ucrt\corecrt_malloc.h(58): Error: extended-decl-modifier expected
#include <stdlib.h>
#endif

#include <stdnoreturn.h>

#include <string.h>

#ifndef _MSC_VER // C:\Program Files (x86)\Windows Kits\10\include\10.0.22621.0\ucrt\tgmath.h(33): Error: no type for declarator before `)`
#ifndef __APPLE__ // /Applications/Xcode-14.2.0.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/tgmath.h(39): Error: named parameter required before `...`
#ifndef __OpenBSD__ // /usr/lib/clang/13.0.0/include/tgmath.h(34): Error: named parameter required before `...`
#if !(defined(__linux__) && defined(__aarch64__)) // /tmp/clang/lib/clang/15.0.3/include/tgmath.h(34): Error: named parameter required before `...`
#include <tgmath.h>
#endif
#endif
#endif
#endif

#ifndef __linux__
#ifndef __APPLE__
#ifndef __OpenBSD__
#ifndef _MSC_VER
#include <threads.h>
#endif
#endif
#endif
#endif

#include <time.h>

#ifndef __APPLE__ // no uchar.h
#include <uchar.h>
#endif

#include <wchar.h>

#include <wctype.h>
