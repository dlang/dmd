
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/root/dsystem.h
 */

#pragma once

// Get common system includes from the host.

#define POSIX (__linux__ || __GLIBC__ || __gnu_hurd__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __DragonFly__  || __sun)

#define __C99FEATURES__ 1       // Needed on Solaris for NaN and more
#define __USE_ISOC99 1          // so signbit() gets defined

#ifndef __STDC_LIMIT_MACROS
#define __STDC_LIMIT_MACROS 1
#endif

#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdarg.h>
#include <stddef.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

#include <new>

#if POSIX
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#endif

// For alloca()
#if _MSC_VER
#include <alloca.h>
#endif
#if defined (__sun)
#include <alloca.h>
#endif

// For getcwd()
#if _WIN32
#include <direct.h>
#endif
#if POSIX
#include <unistd.h>
#endif

// For malloc()
#if _MSC_VER
#include <malloc.h>
#elif __MINGW32__
#include <malloc.h>
#endif

#ifdef __DMC__
// If not present, dmc will error 'number is not representable'.
#undef UINT64_MAX
#define UINT64_MAX      18446744073709551615ULL
#undef UINT32_MAX
#define UINT32_MAX      4294967295U

// If not present, dmc will error 'undefined identifier'.
#ifndef INVALID_FILE_ATTRIBUTES
#define INVALID_FILE_ATTRIBUTES -1L
#endif
#endif
