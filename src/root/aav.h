
/* Copyright (c) 2010-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/aav.h
 */

typedef void* Value;
typedef void* Key;

struct AA;

size_t _aaLen(AA* aa);
Value* _aaGet(AA** aa, Key key);
Value _aaGetRvalue(AA* aa, Key key);
void _aaRehash(AA** paa);

