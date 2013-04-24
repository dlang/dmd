
// Copyright (c) 2013 by Digital Mars
// All Rights Reserved
// written by Iain Buclaw
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <assert.h>

#include "target.h"
#include "mars.h"
#include "mtype.h"

int Target::ptrsize;
int Target::realsize;
int Target::realpad;
int Target::realalignsize;

bool Target::bytesbigendian;
bool Target::wordsbigendian;
bool Target::floatbigendian;

bool hostBytesBigEndian()
{
    const int probe = 0xff;
    return !((*(unsigned char*)&probe) == 0xff);
}

bool hostWordsBigEndian()
{
    const d_uns32 probe = 0xa1b2c3d4;
    //e.g. PDP-11 order: 0xb2, 0xa1, 0xd4, 0xc3 (hostBytesBigEndian() == false; hostWordsBigEndian() == true)
    return hostBytesBigEndian() ? ((*(unsigned char*)&probe) == 0xa1) : ((*(unsigned char*)&probe) == 0xb1);
}

bool hostFloatBigEndian()
{
    const float probe = 1;
    return !!(*cast(ubyte*)&probe);
}



void Target::init()
{
    // These have default values for 32 bit code, they get
    // adjusted for 64 bit code.
    ptrsize = 4;

    if (global.params.isLinux || global.params.isFreeBSD
        || global.params.isOpenBSD || global.params.isSolaris)
    {
        realsize = 12;
        realpad = 2;
        realalignsize = 4;
    }
    else if (global.params.isOSX)
    {
        realsize = 16;
        realpad = 6;
        realalignsize = 16;
    }
    else if (global.params.isWindows)
    {
        realsize = 10;
        realpad = 0;
        realalignsize = 2;
    }
    else
        assert(0);

    if (global.params.is64bit)
    {
        ptrsize = 8;
        if (global.params.isLinux || global.params.isFreeBSD || global.params.isSolaris)
        {
            realsize = 16;
            realpad = 6;
            realalignsize = 16;
        }
    }
    
    bytesbigendian = hostBytesBigEndian();
    wordsbigendian = hostWordsBigEndian();
    floatbigendian = hostFloatBigEndian();
}

unsigned Target::alignsize (Type* type)
{
    assert (type->isTypeBasic());

    switch (type->ty)
    {
        case Tfloat80:
        case Timaginary80:
        case Tcomplex80:
            return Target::realalignsize;

        case Tcomplex32:
            if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD
                || global.params.isOpenBSD || global.params.isSolaris)
                return 4;
            break;

        case Tint64:
        case Tuns64:
        case Tfloat64:
        case Timaginary64:
        case Tcomplex64:
            if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD
                || global.params.isOpenBSD || global.params.isSolaris)
                return global.params.is64bit ? 8 : 4;
            break;

        default:
            break;
    }
    return type->size(0);
}

void Target::toTargetFloatBO (void *p, unsigned size)
{
    if(floatbigendian != hostFloatBigEndian())
    {
        char* c = (char*)p;
        for(unsigned i=0; i<size/2; ++i)
        {
            char tmp = c[i];
            c[i] = c[size - 1 - i];
            c[size - 1 - i] = c[i];
        }
    }
}

void Target::toTargetWordBO (void *p, unsigned size)
{
    if(bytesbigendian != hostBytesBigEndian())
    {
        char* c = (char*)p;
        for(unsigned i=0; i<size/2; ++i)
        {
            char tmp = c[i];
            c[i] = c[size - 1 - i];
            c[size - 1 - i] = c[i];
        }
    }
}

