/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/aa.h, backend/aa.h)
 */


#ifndef AA_H
#define AA_H

typedef size_t hash_t;

struct AAchars
{
    static AAchars* create();
    static void destroy(AAchars*);
    uint* get(const char *s, unsigned len);
    uint length();
};

struct AApair
{
    static AApair* create(unsigned char** pbase);
    static void destroy(AApair*);
    uint* get(uint start, uint end);
    uint length();
};

#endif

