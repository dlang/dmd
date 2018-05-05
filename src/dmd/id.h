
/* Compiler implementation of the D programming language
 * Copyright (C) 2017-2018 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/id.h
 */

#ifndef DMD_ID_H
#define DMD_ID_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

struct Id
{
    static void initialize();
    static void deinitialize();
};

#endif /* DMD_ID_H */
