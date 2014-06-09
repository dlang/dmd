
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/json.h
 */

#ifndef DMD_JSON_H
#define DMD_JSON_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "arraytypes.h"

struct OutBuffer;

void json_generate(OutBuffer *, Modules *);

#endif /* DMD_JSON_H */

