
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2016 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/mars.h
 */

#ifndef DMD_ERRORS_H
#define DMD_ERRORS_H

#ifdef __DMC__
#pragma once
#endif

#include "mars.h"

bool isConsoleColorSupported();

void warning(const Loc& loc, const char *format, ...);
void warningSupplemental(const Loc& loc, const char *format, ...);
void deprecation(const Loc& loc, const char *format, ...);
void deprecationSupplemental(const Loc& loc, const char *format, ...);
void error(const Loc& loc, const char *format, ...);
void errorSupplemental(const Loc& loc, const char *format, ...);
void verror(const Loc& loc, const char *format, va_list ap, const char *p1 = NULL, const char *p2 = NULL, const char *header = "Error: ");
void verrorSupplemental(const Loc& loc, const char *format, va_list ap);
void vwarning(const Loc& loc, const char *format, va_list);
void vwarningSupplemental(const Loc& loc, const char *format, va_list ap);
void vdeprecation(const Loc& loc, const char *format, va_list ap, const char *p1 = NULL, const char *p2 = NULL);
void vdeprecationSupplemental(const Loc& loc, const char *format, va_list ap);

#if defined(__GNUC__) || defined(__clang__)
__attribute__((noreturn))
void fatal();
#elif _MSC_VER
__declspec(noreturn)
void fatal();
#else
void fatal();
#endif

void halt();

#endif /* DMD_ERRORS_H */
