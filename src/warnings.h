
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/mars.h
 */

#ifndef DMD_WARNINGS_H
#define DMD_WARNINGS_H

#ifdef __DMC__
#pragma once
#endif

#include "mars.h"

void warning(Loc loc, const char *format, ...);
void warningSupplemental(Loc loc, const char *format, ...);
void vwarning(Loc loc, const char *format, va_list);
void vwarningSupplemental(Loc loc, const char *format, va_list ap);

#endif /* DMD_WARNINGS_H */
